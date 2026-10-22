# frozen_string_literal: true

Rails.application.configure do
  # Hosts that serve SerpAPI's preview thumbnails for garment search (design doc 6.5). The CSP below and
  # Wardrobe::Search::ImageSearch both read this list, so the page only ever shows thumbnails it allows.
  config.x.search_thumbnail_hosts = %w[
    encrypted-tbn0.gstatic.com encrypted-tbn1.gstatic.com encrypted-tbn2.gstatic.com encrypted-tbn3.gstatic.com
    serpapi.com
  ].freeze

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.img_src :self, :data, "https://storage.googleapis.com", "https://*.googleusercontent.com",
                     "https://www.google-analytics.com",
                     *config.x.search_thumbnail_hosts.map { "https://#{_1}" }
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
