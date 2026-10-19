# frozen_string_literal: true

module Media
  class UnsafeUrlError < ApplicationError; end
  class FetchError < ApplicationError; end

  BLOCKED_HOSTS = %w[metadata.google.internal metadata.azure.com 100.100.100.200].freeze

  class SafeFetcher
    def self.fetch(url, max_bytes: 10.megabytes, timeout: 10)
      new(max_bytes: max_bytes, timeout: timeout).fetch(url)
    end

    def initialize(max_bytes:, timeout:)
      @max_bytes = max_bytes
      @timeout = timeout
    end

    def fetch(url)
      uri = parse_uri!(url)
      check_host!(uri.host)

      response = SsrfFilter.get(uri.to_s, max_redirects: 3, headers: {}, http_options: { open_timeout: @timeout, read_timeout: @timeout })
      body = response.body.to_s
      raise FetchError.new("Response too large") if body.bytesize > @max_bytes

      mime = Marcel::MimeType.for(StringIO.new(body))
      Ai::Image.new(bytes: body, mime_type: mime)
    rescue SsrfFilter::Error => e
      raise UnsafeUrlError.new("URL is not allowed", e.message)
    rescue URI::InvalidURIError, ArgumentError => e
      raise UnsafeUrlError.new("Invalid URL", e.message)
    end

    private

    def parse_uri!(url)
      raise UnsafeUrlError.new("Invalid URL") unless url.to_s.match?(%r{\Ahttps?://}i)

      URI.parse(url)
    end

    def check_host!(host)
      raise UnsafeUrlError.new("Blocked host") if BLOCKED_HOSTS.include?(host.to_s.downcase)
    end
  end
end
