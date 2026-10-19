# frozen_string_literal: true

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.img_src :self, :data, "https://storage.googleapis.com", "https://*.googleusercontent.com",
                     "https://www.google-analytics.com"
    policy.script_src :self, "https://www.googletagmanager.com"
    policy.style_src :self, :unsafe_inline, "https://fonts.googleapis.com"
    policy.font_src :self, "https://fonts.gstatic.com", :data
    policy.connect_src :self
    policy.frame_ancestors :none
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]

  config.action_dispatch.default_headers.merge!(
    "X-Frame-Options" => "DENY",
    "Referrer-Policy" => "strict-origin-when-cross-origin"
  )
end
