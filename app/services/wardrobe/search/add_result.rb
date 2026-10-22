# frozen_string_literal: true

module Wardrobe
  module Search
    # Adds a picked search result to the wardrobe (design doc 6.5 "Pick a result"): saves the garment right
    # away with image_status "pending" and queues Wardrobe::ImportRemoteImageJob to download the image.
    #
    #   AddResult.call(user:, image_url:, title:, source_url:, attributes: { brand:, keywords:, category:, ... })
    #   # => Garment; raises Wardrobe::Search::Error (unusable image link) or ActiveRecord::RecordInvalid
    #
    # image_url is untrusted. Only its shape is checked here; Media::SafeFetcher decides in the job whether
    # it may be fetched.
    class AddResult
      MAX_URL_LENGTH = 2048
      UNUSABLE_IMAGE = "That image can't be used. Pick another result."
      DEFAULTS = { formality: "casual", seasonality: "all_season" }.freeze # same defaults as manual add

      def self.call(user:, image_url:, title:, source_url:, attributes:)
        new(user:, image_url:, title:, source_url:, attributes:).call
      end

      def initialize(user:, image_url:, title:, source_url:, attributes:)
        @user = user
        @image_url = image_url
        @title = title.to_s.squish
        @source_url = source_url
        @attrs = attributes.to_h.symbolize_keys
      end

      def call
        raise Error.new(UNUSABLE_IMAGE, status: :unprocessable_entity) unless web_url?(@image_url)

        garment = Garment.create!(
          user: @user,
          name: name,
          category: category,
          sub_category: Garment.normalize_kind(@attrs[:kind]),
          color_primary: @attrs[:color],
          material: @attrs[:material],
          brand: @attrs[:brand],
          formality: @attrs[:formality].presence || DEFAULTS[:formality],
          seasonality: @attrs[:seasonality].presence || DEFAULTS[:seasonality],
          gender: @attrs[:gender].to_s.presence_in(%w[men women]),
          source: "search",
          source_url: (@source_url if web_url?(@source_url)),
          image_status: "pending"
        )
        ActiveRecord.after_all_transactions_commit do
          Wardrobe::ImportRemoteImageJob.perform_later(garment.id, @image_url)
        end
        garment
      end

      private

      # "the title trimmed to 80 characters, or the keywords" (design doc 6.5)
      def name
        (@title.presence || @attrs[:keywords].to_s.squish).first(Garment::NAME_MAX_LENGTH).strip
      end

      # The form's category, else the category of the chosen kind, else a garment noun in the title or
      # keywords (e.g. "white shirt" -> top). Without any of them the garment fails validation.
      def category
        @attrs[:category].to_s.presence_in(Garment::CATEGORIES) || category_from_kind || category_from_words
      end

      def category_from_kind
        kind = @attrs[:kind].to_s.downcase
        return if kind.blank?

        Options.fetch(:search_kinds_by_category).find { |_cat, kinds| kinds.map(&:downcase).include?(kind) }&.first&.to_s
      end

      def category_from_words
        tokens = FilterAndRank.tokenize("#{@title} #{@attrs[:keywords]}")
        WordLists::CATEGORY_BY_NOUN.find { |_cat, nouns| tokens.intersect?(nouns) }&.first
      end

      def web_url?(value)
        return false unless value.is_a?(String) && value.length <= MAX_URL_LENGTH

        URI.parse(value).then { _1.is_a?(URI::HTTP) && _1.host.present? }
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
