# frozen_string_literal: true

class Rack::Attack
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.post? && req.path == "/users/sign_in"
  end

  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.post? && req.path == "/users/sign_in"
      req.params.dig("user", "email").to_s.downcase.presence
    end
  end

  AI_POST_PATHS = %w[
    /wardrobe/photo_intakes
    /wardrobe/receipts
    /avatar
  ].freeze

  # Signed-in user's id from the Warden session; nil (not throttled here) when signed out.
  SESSION_USER_ID = ->(req) { req.session["warden.user.user.key"]&.dig(0, 0) }

  throttle("ai/user/min", limit: 10, period: 1.minute) do |req|
    next unless req.post? && AI_POST_PATHS.any? { |p| req.path.start_with?(p) }

    SESSION_USER_ID.call(req)
  end

  # Garment search (design doc 4.4: 10 per minute per user). Each search can cost two SerpAPI calls.
  # Exact path, so adding a result (/wardrobe/searches/select) does not spend this budget.
  throttle("search/user/min", limit: 10, period: 1.minute) do |req|
    SESSION_USER_ID.call(req) if req.post? && req.path == "/wardrobe/searches"
  end

  # Adding a search result is a database insert plus a background download through Media::SafeFetcher:
  # cheaper than a search, but still bounded so the import queue cannot be flooded.
  throttle("search-select/user/min", limit: 30, period: 1.minute) do |req|
    SESSION_USER_ID.call(req) if req.post? && req.path == "/wardrobe/searches/select"
  end

  throttle("api/metrics/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.get? && req.path == "/api/metrics"
  end

  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "text/plain" }, [ "Retry later\n" ] ]
  end
end
