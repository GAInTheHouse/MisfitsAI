# frozen_string_literal: true

module Wardrobe
  module Search
    # Scores, filters and orders raw Google Images results so product photos of the wanted garment come first
    # (design doc 6.5, port of garment_search_filter.py's algorithm).
    #
    #   FilterAndRank.call(results, base_query:, color:, material:, kind:, limit:) # => Array<Hash> (SerpAPI items)
    class FilterAndRank
      include WordLists

      NEGATIVE_PENALTY = -4.0
      REQUIRED_MATCH_BONUS = 3.0
      NO_REQUIRED_MATCH_PENALTY = -2.0
      APPAREL_HINT_BONUS = 0.4
      APPAREL_HINT_CAP = 2.0
      KEEP_ABOVE = -8.0
      WHOLE_WORD_MAX_LENGTH = 5

      def self.call(results, base_query:, color: nil, material: nil, kind: nil, limit: 8)
        new(base_query:, color:, material:, kind:).call(results, limit:)
      end

      def self.tokenize(text)
        text.to_s.downcase.scan(/[a-z0-9]+/).select { _1.length >= 3 }
      end

      # Short tokens must be whole words ("top" must not match "laptop"); longer ones may be substrings.
      def self.token_match?(blob, token)
        if token.length <= WHOLE_WORD_MAX_LENGTH
          blob.match?(/(?<![a-z0-9])#{Regexp.escape(token)}(?![a-z0-9])/)
        else
          blob.include?(token)
        end
      end

      def initialize(base_query:, color:, material:, kind:)
        @required = (self.class.tokenize([ base_query, color, material, kind ].compact.join(" ")) - STOPWORDS.to_a).uniq
      end

      def call(results, limit:)
        scored = results.each_with_index.map { |result, index| [ result, score(blob(result)), index ] }
        # Highest score first; ties keep their original order (stable).
        ranked = scored.sort_by { |_result, score, index| [ -score, index ] }

        kept = ranked.select { |result, score, _| score > KEEP_ABOVE && garment_noun?(blob(result)) }
        kept = ranked.select { |result, _, _| garment_noun?(blob(result)) } if kept.empty?
        kept = ranked if kept.empty?

        kept.map(&:first).uniq { image_url(_1) }.first(limit)
      end

      def score(blob)
        value = 0.0
        value += NEGATIVE_PENALTY * NEGATIVE_WORDS.count { self.class.token_match?(blob, _1) }
        matched = @required.count { self.class.token_match?(blob, _1) }
        value += REQUIRED_MATCH_BONUS * matched
        value += NO_REQUIRED_MATCH_PENALTY if @required.any? && matched.zero?
        value + [ APPAREL_HINT_CAP, APPAREL_HINT_BONUS * APPAREL_HINTS.count { self.class.token_match?(blob, _1) } ].min
      end

      private

      def blob(result)
        "#{result['title']} #{result['link']} #{result['original']} #{result['thumbnail']}".downcase
      end

      def garment_noun?(blob)
        GARMENT_NOUNS.any? { self.class.token_match?(blob, _1) }
      end

      def image_url(result)
        result["original"].presence || result["thumbnail"]
      end
    end
  end
end
