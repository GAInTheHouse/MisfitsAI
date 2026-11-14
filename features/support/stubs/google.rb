# frozen_string_literal: true

# Google Calendar and OAuth token stubs for Phase 3 (design doc 8.2). WebMock blocks every real request.
module GoogleStubs
  CALENDAR_EVENTS_URL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
  TOKEN_URL = "https://oauth2.googleapis.com/token"

  # events: Array of { summary:, date: "YYYY-MM-DD", time: "HH:MM" | "all day" | nil }, in the user's zone.
  # Rows without a time start at 09:00 plus one minute per row, so a day's events keep the table order.
  def stub_google_calendar(events:, time_zone: "America/New_York")
    items = events.each_with_index.map do |event, index|
      start =
        if event[:time] == "all day"
          { date: event[:date] }
        else
          time = event[:time].presence || format("09:%02d", index)
          { dateTime: Time.find_zone!(time_zone).parse("#{event[:date]} #{time}").iso8601 }
        end
      { id: "evt-#{index}", summary: event[:summary], start: }
    end
    stub_request(:get, CALENDAR_EVENTS_URL).with(query: hash_including({}))
                                           .to_return(status: 200, body: { items: }.to_json, headers: json_headers)
  end

  def stub_google_calendar_failure(status:)
    stub_request(:get, CALENDAR_EVENTS_URL).with(query: hash_including({}))
                                           .to_return(status:, body: { error: { code: status } }.to_json,
                                                      headers: json_headers)
  end

  def stub_google_token_refresh(access_token: "refreshed-access-token")
    stub_request(:post, TOKEN_URL).to_return(
      status: 200, headers: json_headers,
      body: { access_token:, expires_in: 3600, token_type: "Bearer" }.to_json
    )
  end

  def stub_google_token_revoked
    stub_request(:post, TOKEN_URL).to_return(
      status: 400, headers: json_headers,
      body: { error: "invalid_grant", error_description: "Token has been expired or revoked." }.to_json
    )
  end

  private

  def json_headers
    { "Content-Type" => "application/json" }
  end
end

World(GoogleStubs)
