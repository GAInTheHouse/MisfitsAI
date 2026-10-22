# frozen_string_literal: true

module Media
  # Fetches a user-influenced URL (e.g. a search result image) without letting it reach internal services
  # (design doc 4.4). Every hop, including redirects, must:
  # - use http or https on the default port, with no credentials in the URL;
  # - not name a blocked metadata host;
  # - resolve only to public addresses. ssrf_filter checks the IPs and connects to the vetted IP, so a
  #   second DNS answer (rebinding) cannot redirect the connection.
  # The response must be 2xx and is read in chunks under a byte limit and an overall deadline.
  # The caller still checks the bytes are an image (Media::ImageNormalizer.sniff!).
  #
  #   Media::SafeFetcher.fetch(url, max_bytes: 10.megabytes, timeout: 10) # => Ai::Image(bytes, mime_type)
  #   raises Media::UnsafeUrlError (never fetched) or Media::FetchError (could not download); the subclass
  #   Media::TransientFetchError marks failures worth retrying (timeouts, network errors, HTTP 408/429/5xx)
  class SafeFetcher
    BLOCKED_HOSTS = %w[metadata.google.internal metadata.azure.com 100.100.100.200].freeze
    ALLOWED_PORTS = { "http" => 80, "https" => 443 }.freeze
    MAX_REDIRECTS = 3
    RETRYABLE_STATUSES = [ 408, 429 ].freeze # plus every 5xx
    USER_AGENT = "misfitAI-image-import/1.0"

    # Network failures that mean "could not download", not "unsafe".
    NETWORK_ERRORS = [
      Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, SocketError, SystemCallError,
      IOError, EOFError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Zlib::Error
    ].freeze

    # DNS lookup used for every hop. Tests replace it so no real DNS is used.
    cattr_accessor :resolver, default: SsrfFilter::DEFAULT_RESOLVER

    def self.fetch(url, max_bytes: 10.megabytes, timeout: 10)
      new(max_bytes: max_bytes, timeout: timeout).fetch(url)
    end

    def initialize(max_bytes:, timeout:)
      @max_bytes = max_bytes
      @timeout = timeout
    end

    def fetch(url)
      uri = parse_uri!(url)
      check_uri!(uri)
      deadline = monotonic_now + @timeout
      body = +"".b
      response = SsrfFilter.get(
        uri.to_s,
        max_redirects: MAX_REDIRECTS,
        resolver: method(:resolve),
        headers: { "User-Agent" => USER_AGENT, "Accept" => "image/*" },
        request_proc: ->(request) { check_uri!(request.uri) }, # redirect hops too
        http_options: { open_timeout: @timeout, read_timeout: @timeout, write_timeout: @timeout }
      ) { |res| read_body(res, body, deadline) }

      unless response.is_a?(Net::HTTPSuccess)
        error = retryable_status?(response.code.to_i) ? TransientFetchError : FetchError
        raise error.new("Couldn't download that image.", "HTTP #{response.code}")
      end

      Ai::Image.new(bytes: body, mime_type: Marcel::MimeType.for(StringIO.new(body)))
    rescue SsrfFilter::TooManyRedirects, SsrfFilter::UnresolvedHostname => e
      raise FetchError.new("Couldn't download that image.", e.class.name)
    rescue SsrfFilter::Error => e
      raise UnsafeUrlError.new("URL is not allowed", e.class.name)
    rescue *NETWORK_ERRORS => e
      raise TransientFetchError.new("Couldn't download that image.", e.class.name)
    end

    private

    def parse_uri!(url)
      raise UnsafeUrlError.new("Invalid URL") unless url.is_a?(String) && url.match?(%r{\Ahttps?://}i)

      URI.parse(url)
    rescue URI::InvalidURIError
      raise UnsafeUrlError.new("Invalid URL")
    end

    def check_uri!(uri)
      raise UnsafeUrlError.new("URL is not allowed", "scheme") unless ALLOWED_PORTS.key?(uri.scheme.to_s.downcase)
      raise UnsafeUrlError.new("URL is not allowed", "credentials") if uri.userinfo.present?
      raise UnsafeUrlError.new("URL is not allowed", "port") unless uri.port == ALLOWED_PORTS[uri.scheme.downcase]
      raise UnsafeUrlError.new("URL is not allowed", "host") if uri.hostname.blank?
    end

    def resolve(hostname)
      raise UnsafeUrlError.new("URL is not allowed", "blocked host") if BLOCKED_HOSTS.include?(hostname.to_s.downcase.chomp("."))

      resolver.call(hostname)
    end

    # Called by ssrf_filter for every response, redirects included. Only a 2xx body is read.
    def read_body(response, body, deadline)
      return unless response.is_a?(Net::HTTPSuccess)
      raise FetchError.new("Image is too large", "content-length") if response.content_length.to_i > @max_bytes

      response.read_body do |chunk|
        body << chunk
        raise FetchError.new("Image is too large", "body") if body.bytesize > @max_bytes
        raise TransientFetchError.new("Couldn't download that image.", "deadline") if monotonic_now > deadline
      end
    end

    def retryable_status?(status)
      status >= 500 || RETRYABLE_STATUSES.include?(status)
    end

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end
  end
end
