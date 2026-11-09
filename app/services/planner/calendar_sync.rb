# frozen_string_literal: true

require "google/apis/calendar_v3"
require "signet/oauth_2/client"

module Planner
  class CalendarSync
    class SyncError < StandardError; end

    def initialize(user:)
      @user = user
    end

    def sync!
      return false unless Feature.enabled?(:calendar_sync)

      @week_start = Week.current_start(@user)
      @plan = WeekPlanner.ensure_week!(user: @user)
      return broadcast_reconnect! unless refresh_token!

      sync_once!
    rescue Google::Apis::AuthorizationError
      return broadcast_reconnect! unless refresh_token!(force: true)

      sync_once!
    rescue Google::Apis::ClientError, Signet::AuthorizationError
      broadcast_reconnect!
    rescue StandardError => e
      Rails.logger.warn("Calendar sync failed: #{e.class}: #{e.message}")
      false
    end

    def sync_once!
      events = list_calendar_events(@week_start)
      apply_events!(@plan, @week_start, events)
      @plan.update!(source: "google", synced_at: Time.current)
      @user.update!(google_calendar_connected_at: @user.google_calendar_connected_at || Time.current)
      broadcast_week_plan!(@plan)
      true
    end

    private

    def refresh_token!(force: false)
      return false if @user.google_refresh_token.blank?

      if !force && @user.google_token_expires_at.present? && @user.google_token_expires_at > 60.seconds.from_now
        return true
      end

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
      @user.update!(google_access_token: nil, google_refresh_token: nil, google_token_expires_at: nil)
      false
    end

    def calendar_service
      @calendar_service ||= begin
        service = Google::Apis::CalendarV3::CalendarService.new
        service.authorization = @user.google_access_token
        service
      end
    end

    def list_calendar_events(week_start)
      tz = @user.time_zone
      time_min = week_start.in_time_zone(tz).beginning_of_day.iso8601
      time_max = (week_start + 6).in_time_zone(tz).end_of_day.iso8601

      calendar_service.list_events(
        "primary",
        time_min: time_min,
        time_max: time_max,
        single_events: true,
        order_by: "startTime",
        max_results: 250
      ).items || []
    end

    def apply_events!(plan, week_start, items)
      by_date = Hash.new { |h, k| h[k] = [] }
      items.each do |item|
        date = event_date(item)
        next unless date && date >= week_start && date <= week_start + 6

        by_date[date] << item
      end

      winners = {}
      by_date.each do |date, day_items|
        sorted = day_items.sort_by { |i| i.start&.date_time || i.start&.date || "" }
        winner = nil
        sorted.each do |item|
          classified = EventClassifier.call(item.summary.to_s)
          prio = EventClassifier.priority(classified)
          next unless winner.nil? || prio > winner[:priority]

          winner = { type: classified, summary: item.summary.to_s, priority: prio }
        end
        winners[date] = winner
      end

      (0..6).each do |offset|
        date = week_start + offset
        win = winners[date]
        event = plan.week_events.find_or_initialize_by(date: date)
        if win
          event.event_type = win[:type]
          event.original_summary = win[:summary]
        else
          event.event_type = "none"
          event.original_summary = nil
        end
        event.save!
      end
    end

    def event_date(item)
      tz = @user.time_zone
      if item.start&.date
        item.start.date
      elsif item.start&.date_time
        item.start.date_time.in_time_zone(tz).to_date
      end
    end

    def broadcast_week_plan!(plan)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ @user, :planner ],
        target: "week_plan",
        partial: "week_plans/week_plan",
        locals: { week_plan: plan }
      )
    end

    def broadcast_reconnect!
      Rails.logger.info("Calendar sync: user #{@user.id} needs Google reconnect")
      false
    end
  end
end
