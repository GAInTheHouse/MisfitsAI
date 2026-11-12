# frozen_string_literal: true

require "google/apis/calendar_v3"
require "signet/oauth_2/client"

module Planner
  # Imports the current week's Google Calendar events into the user's week plan (design doc 6.7).
  # Returns true on success, false otherwise; every outcome is also broadcast to the planner stream.
  class CalendarSync
    RECONNECT_MESSAGE = "Your Google connection expired. Please reconnect."
    UNREACHABLE_MESSAGE = "Couldn't reach Google Calendar. Please try again."
    SUCCESS_MESSAGE = "Your Google Calendar week is synced."

    def initialize(user:)
      @user = user
    end

    def sync!
      return false unless Feature.enabled?(:calendar_sync)

      @week_start = Week.current_start(@user)
      @plan = WeekPlanner.ensure_week!(user: @user)
      return reconnect! unless refresh_token!

      begin
        sync_once!
      rescue Google::Apis::AuthorizationError
        # 6.7 step 9: a 401 means refresh once and retry. A second 401 reaches the outer rescue.
        return reconnect! unless refresh_token!(force: true)

        sync_once!
      end
    rescue Google::Apis::AuthorizationError
      reconnect!
    rescue StandardError => e
      Rails.logger.warn("Calendar sync failed: #{e.class}: #{e.message}")
      broadcast_status!(UNREACHABLE_MESSAGE, tone: :alert)
      false
    end

    private

    def sync_once!
      events = list_calendar_events
      apply_events!(events)
      @plan.update!(source: "google", synced_at: Time.current)
      @user.update!(google_calendar_connected_at: @user.google_calendar_connected_at || Time.current)
      broadcast_week_plan!
      broadcast_status!(SUCCESS_MESSAGE, tone: :notice)
      true
    end

    def refresh_token!(force: false)
      return false if @user.google_refresh_token.blank?
      return true if !force && @user.google_token_expires_at.present? && @user.google_token_expires_at > 60.seconds.from_now

      client = Signet::OAuth2::Client.new(
        client_id: ENV.fetch("GOOGLE_CLIENT_ID", ""),
        client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET", ""),
        token_credential_uri: "https://oauth2.googleapis.com/token",
        refresh_token: @user.google_refresh_token
      )
      client.fetch_access_token!
      @user.update!(
        google_access_token: client.access_token,
        google_token_expires_at: Time.current + client.expires_in.to_i.seconds
      )
      true
    rescue Signet::AuthorizationError
      false
    end

    def calendar_service
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = @user.google_access_token # read each call: a retry uses the refreshed token
      service
    end

    def list_calendar_events
      tz = @user.time_zone
      calendar_service.list_events(
        "primary",
        time_min: @week_start.in_time_zone(tz).beginning_of_day.iso8601,
        time_max: (@week_start + 6).in_time_zone(tz).end_of_day.iso8601,
        single_events: true,
        order_by: "startTime",
        max_results: 250
      ).items || []
    end

    def apply_events!(items)
      week = @week_start..(@week_start + 6)
      winners = {}
      # Start-time order, Google's order breaking ties, so the first event wins a same-priority tie (6.7 step 6).
      timed = items.each_with_index.filter_map do |item, index|
        date, starts_at = event_date_and_start(item)
        [ date, starts_at, index, item ] if date && week.cover?(date)
      end
      timed.sort_by { |_date, starts_at, index, _item| [ starts_at, index ] }.each do |date, _starts_at, _index, item|
        type = EventClassifier.call(item.summary)
        current = winners[date]
        next if current && EventClassifier.priority(type) <= EventClassifier.priority(current[:type])

        winners[date] = { type:, summary: item.summary.to_s }
      end

      week.each do |date|
        event = @plan.week_events.find_or_initialize_by(date:)
        event.event_type = winners.dig(date, :type) || "none"
        event.original_summary = winners.dig(date, :summary)
        event.save!
      end
    end

    # 6.7 step 4: all-day events use start.date; timed events use the start time in the user's zone.
    def event_date_and_start(item)
      tz = @user.time_zone
      if item.start&.date.present?
        date = item.start.date.to_date
        [ date, date.in_time_zone(tz) ]
      elsif item.start&.date_time.present?
        starts_at = item.start.date_time.in_time_zone(tz)
        [ starts_at.to_date, starts_at ]
      end
    end

    def reconnect!
      Rails.logger.info("Calendar sync: user #{@user.id} needs Google reconnect")
      @user.update!(google_access_token: nil, google_refresh_token: nil, google_token_expires_at: nil)
      broadcast_status!(RECONNECT_MESSAGE, tone: :alert)
      false
    end

    def broadcast_week_plan!
      Turbo::StreamsChannel.broadcast_replace_to(
        [ @user, :planner ],
        target: "week_plan",
        partial: "week_plans/week_plan",
        locals: { week_plan: @plan }
      )
    end

    def broadcast_status!(message, tone:)
      Turbo::StreamsChannel.broadcast_update_to(
        [ @user, :planner ],
        target: "calendar_sync_status",
        partial: "week_plans/sync_status",
        locals: { message:, tone: }
      )
    end
  end
end
