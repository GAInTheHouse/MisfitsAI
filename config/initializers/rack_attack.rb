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
    /wardrobe/searches
    /wardrobe/receipts
    /avatar
  ].freeze

  throttle("ai/user/min", limit: 10, period: 1.minute) do |req|
    next unless req.post? && AI_POST_PATHS.any? { |p| req.path.start_with?(p) }

    req.session["warden.user.user.key"]&.dig(0, 0)
  end

  throttle("api/metrics/ip", limit: 30, period: 1.minute) do |req|
    req.ip if req.get? && req.path == "/api/metrics"
  end

  self.throttled_responder = lambda do |_env|
    [ 429, { "Content-Type" => "text/plain" }, [ "Retry later\n" ] ]
  end
end
