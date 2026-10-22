# frozen_string_literal: true

module Wardrobe
  module Search
    # Google Images search through SerpAPI for product photos (design doc 6.5). Runs inside the request; the
    # timeouts keep it well under Heroku's 30 s limit.
    #
    #   ImageSearch.call(query: "Uniqlo white shirt", color: "White", material: nil, kind: "Oxford shirt",
    #                    gender: "men", limit: 8)
    #   # => [{ image_url:, thumbnail_url:, title:, source_url: }, ...]
    #   raises Wardrobe::Search::Error with one of the messages below
    #
    # The API key only ever goes into the outgoing request's query string: it is never logged, put in an
    # error message, a cache key or a response.
    class ImageSearch
      ENDPOINT = "https://serpapi.com/search.json"
      OPEN_TIMEOUT = 4
      READ_TIMEOUT = 8
      CACHE_TTL = 24.hours # design doc 11.5: protects the SerpAPI free quota
      PRODUCT_TERMS = "clothing product photo, studio, on white background"
      EXCLUDED_TERMS = "-person -people -model -man -woman -face -selfie"

      MISSING_QUERY = "Enter a brand or keywords"
      NOT_CONFIGURED = "Garment search is not configured"
      PROVIDER_FAILED = "Garment search provider failed. Try again later."
      REQUEST_FAILED = "Garment search request failed. Please retry."

      def self.call(query:, color: nil, material: nil, kind: nil, gender: nil, limit: 8)
        new(query:, color:, material:, kind:, gender:, limit:).call
      end

      def initialize(query:, color:, material:, kind:, gender:, limit:)
        @base_query = query.to_s.squish
        @color = color.presence
        @material = material.presence
        @kind = kind.presence
        @gender = gender.to_s.downcase.presence_in(%w[men women])
        @limit = limit.to_i.clamp(1, 20)
      end

      def call
        raise Error.new(MISSING_QUERY, status: :unprocessable_entity) if @base_query.blank?

        api_key = ENV["SERPAPI_KEY"].presence
        raise Error.new(NOT_CONFIGURED, status: :service_unavailable) unless api_key

        Rails.cache.fetch([ "garment-image-search/v1", Digest::SHA256.hexdigest([ q, @limit ].join("|")) ],
                          expires_in: CACHE_TTL) { search(api_key) }
      end

      # The full Google Images query (design doc 6.5 step 3, in this order).
      def q
        [
          @base_query,
          (@gender && "for #{@gender}"),
          @color, @material, @kind,
          PRODUCT_TERMS,
          EXCLUDED_TERMS
        ].compact.join(" ")
      end

      private

      def search(api_key)
        raw = dedupe(fetch_page(api_key, page: 0))
        filtered = rank(raw)

        # Backfill from page 2 when page 1 leaves too few (design doc 6.5 step 7). At most two SerpAPI calls.
        if filtered.size < backfill_threshold
          begin
            raw = dedupe(raw + fetch_page(api_key, page: 1))
            filtered = rank(raw)
          rescue Error => e
            Rails.logger.warn("[Wardrobe::Search] page 2 failed (#{e.message}); keeping page 1 results")
          end
        end

        filtered.map do |result|
          { image_url: image_url(result), thumbnail_url: preview_url(result),
            title: result["title"].to_s.squish, source_url: result["link"].presence }
        end
      end

      def backfill_threshold
        [ @limit, [ 2, (@limit + 1) / 2 ].max ].min
      end

      def rank(raw)
        FilterAndRank.call(raw, base_query: @base_query, color: @color, material: @material, kind: @kind, limit: @limit)
      end

      # The browser only ever loads a thumbnail from a host the CSP allows (config.x.search_thumbnail_hosts);
      # any other result gets no preview, so the page never contacts an arbitrary host.
      def preview_url(result)
        url = result["thumbnail"]
        url if URI.parse(url).then { _1.is_a?(URI::HTTPS) && _1.host.in?(Rails.configuration.x.search_thumbnail_hosts) }
      rescue URI::InvalidURIError, TypeError
        nil
      end

      def fetch_page(api_key, page:)
        params = { engine: "google_images", q: q, api_key: api_key, num: @limit }
        params[:ijn] = page if page.positive?
        response = connection.get(ENDPOINT, params)
        unless response.status.between?(200, 299)
          Rails.logger.warn("[Wardrobe::Search] SerpAPI responded #{response.status}")
          raise Error.new(PROVIDER_FAILED, status: :bad_gateway, internal_message: "HTTP #{response.status}")
        end

        results_from(response.body, api_key)
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
        Rails.logger.warn("[Wardrobe::Search] SerpAPI request failed: #{e.class}")
        raise Error.new(REQUEST_FAILED, status: :gateway_timeout, internal_message: e.class.name)
      end

      def results_from(body, api_key)
        json = JSON.parse(body)
        # SerpAPI answers 200 with an "error" when Google simply found nothing; that is an empty result.
        if json["error"].present?
          return [] if json["error"].match?(/hasn't returned any results/i)

          raise Error.new(PROVIDER_FAILED, status: :bad_gateway, internal_message: "SerpAPI error")
        end
        Array(json["images_results"]).filter_map { web_urls_only(_1, api_key) if _1.is_a?(Hash) }
      rescue JSON::ParserError
        raise Error.new(PROVIDER_FAILED, status: :bad_gateway, internal_message: "invalid JSON")
      end

      # Keeps only plain http(s) links (Google sometimes returns data: URIs) and drops results without an image.
      # A link that carries our API key, or any api_key parameter, is dropped too, so it can never reach the page.
      def web_urls_only(result, api_key)
        result = result.merge(%w[original thumbnail link].to_h { [ _1, (result[_1] if web_url?(result[_1], api_key)) ] })
        result if result["original"] || result["thumbnail"]
      end

      def web_url?(value, api_key)
        return false unless value.is_a?(String) && value.length <= 2048 && !value.include?(api_key)

        uri = URI.parse(value)
        uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil? &&
          URI.decode_www_form(uri.query.to_s).none? { |key, _| key.casecmp?("api_key") }
      rescue URI::InvalidURIError, ArgumentError
        false
      end

      def dedupe(results)
        results.uniq { image_url(_1) }
      end

      def image_url(result)
        result["original"].presence || result["thumbnail"]
      end

      def connection
        Faraday.new do |f|
          f.options.open_timeout = OPEN_TIMEOUT
          f.options.timeout = READ_TIMEOUT
          f.adapter Faraday.default_adapter
        end
      end
    end
  end
end
