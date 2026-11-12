# frozen_string_literal: true

module Planner
  # Pure rules-based outfit selection (design doc 6.8).
  class RecommendationEngine
    TOP_SUBCATEGORIES = %w[shirt blouse sweater t-shirt t_shirt tank_top blazer vest jacket halter_neck
      activewear_top crop_top cardigan bodysuit hoodie polo turtleneck henley flannel sweatshirt].to_set
    BOTTOM_SUBCATEGORIES = %w[pants jeans trousers skirt shorts leggings activewear_bottom culottes chinos
      sweatpants cargo_pants dress_pants wide_leg_pants].to_set

    FORMALITY_CHAINS = {
      "work_meeting" => [ %w[formal business], %w[smart_casual] ],
      "date_night"   => [ %w[smart_casual], %w[casual], %w[formal business] ],
      "gym"          => [ %w[casual], %w[smart_casual] ],
      "casual"       => [ %w[casual], %w[smart_casual] ]
    }.freeze
    FALLBACK_CHAIN = [ %w[casual], %w[smart_casual] ].freeze

    EXCLUDED_SUBCATEGORIES = {
      "work_meeting" => %w[tank_top crop_top graphic_tee halter_neck bodysuit hoodie].to_set,
      "gym"          => %w[blazer vest oxford heels pumps loafers dress_pants].to_set
    }.freeze

    GYM_TAILORING_SUBSTRINGS = [ "blazer", "tux", "tailored jacket", "tailored trouser", "dress pant",
      "dress shirt", "oxford shirt", "pencil skirt", "stiletto", "pump" ].freeze
    GYM_DRESS_SHOE_RE = /\b(heels?|pumps?|stilettos?|oxfords?|loafers?)\b/i
    SUIT_WORD_RE      = /\bsuit\b/i

    SIZE_BANDS = [ %w[xxs 00 0], %w[xs 2 4 6], %w[s small 8 10], %w[m medium 12 14], %w[l large 16 18],
      %w[xl x-large 20 22], %w[xxl 2xl 24 26], %w[xxxl 3xl 28 30] ].map(&:to_set).freeze

    WARM_COLORS = %w[red orange yellow gold amber coral rust terracotta brown beige tan camel sand cream
      ivory olive mustard peach salmon].to_set
    COOL_COLORS = %w[blue navy indigo violet purple lilac lavender teal cyan turquoise mint green sage
      emerald grey gray silver white black].to_set
    COLOR_MATCH_BONUS   = 0.5
    COLOR_AVOID_PENALTY = -2.0
    COLOR_TONE_BONUS    = 0.2

    STRUCTURED_TOP_RE = /\b(blazer|sport coat|suit jacket|suit coat|double-breasted|peacoat)\b/i
    DRESS_SHOE_RE     = /\b(heel|pump|stiletto|oxford|loafer|wingtip|brogue)s?\b/i
    OUTERWEAR_EVENTS  = %w[work_meeting casual].to_set

    # events: anything with #date and #event_type, in order: WeekEvents (one outfit per day) or
    # Planner::Segments (issue #8, one outfit per time block; a segment's #chain overrides the formality chain).
    # recently_worn_ids: garment ids the user confirmed wearing lately; they lose ties to unworn pieces.
    def self.call(garments:, events:, context:, recently_worn_ids: Set.new)
      new(garments:, events:, context:, recently_worn_ids:).call
    end

    def initialize(garments:, events:, context:, recently_worn_ids: Set.new)
      @garments = garments
      @events = events
      @context = context
      @recently_worn = recently_worn_ids.to_set
      @avoid_words = color_word_set(@context.avoided_colors)
      @fav_words = color_word_set(@context.favorite_colors)
      @tone = @context.color_tone&.to_s&.downcase
    end

    def call
      pool  = apply_gender_filter(@garments).reject(&:hidden_from_recommendations)
      label = size_label(@context.measurements)
      used  = Set.new

      @events.each_with_index.map do |event, day_index|
        displayed = event.event_type
        type      = displayed == "none" ? "casual" : displayed
        chain     = (event.chain if event.respond_to?(:chain)) || FORMALITY_CHAINS.fetch(type, FALLBACK_CHAIN)
        gym       = type == "gym" ? method(:gym_allowed?) : nil
        tiebreak  = type == "work_meeting" ? ->(g) { structured_jacket?(g) ? 1 : 0 } : nil

        top = bottom = dress = nil
        if type == "date_night"
          dress = pick(pool, method(:dress?), chain, used:, event_type: type, label:, allow_reuse: false)
        end

        unless dress
          top    = pick(pool, method(:top?), chain, used:, event_type: type, label:, extra: gym, tiebreak:)
          bottom = pick(pool, method(:bottom?), chain, used:, event_type: type, label:, extra: gym)
          if top.nil? || bottom.nil?
            fallback = pick(pool, method(:dress?), chain, used:, event_type: type, label:, extra: gym)
            if fallback
              dress = fallback
              top = bottom = nil
            end
          end
        end

        [ top, bottom, dress ].compact.each { used << _1.id }

        outerwear = pick_outerwear(pool, top:, displayed:, day_index:)
        shoes     = pick_shoes(pool, type:, chain:, label:, used:)

        DaySuggestion.new(
          date: event.date, event_type: displayed, top:, bottom:, dress:, outerwear:, shoes:
        )
      end
    end

    private

    def normalize(str)
      str.to_s.strip.downcase.gsub(/[\s\-]+/, "_")
    end

    def sub_key(g)
      normalize(g.sub_category.presence || g.name)
    end

    def blob(g)
      [ g.category, g.name, g.sub_category, g.material, g.fit_notes, *g.tags ].compact.join(" ")
        .downcase.tr("_", " ")
    end

    def top?(g)
      g.category == "top" && !BOTTOM_SUBCATEGORIES.include?(normalize(g.sub_category))
    end

    def bottom?(g)
      g.category == "bottom" && !TOP_SUBCATEGORIES.include?(normalize(g.sub_category))
    end

    def dress?(g)
      g.category == "dress"
    end

    def gym_allowed?(g)
      b = blob(g)
      return false if SUIT_WORD_RE.match?(b)
      return false if GYM_DRESS_SHOE_RE.match?(b)

      GYM_TAILORING_SUBSTRINGS.none? { b.include?(_1) }
    end

    def structured_jacket?(g)
      b = blob(g)
      b.include?("blazer") || b.include?("sport coat") || b.include?("suit jacket") ||
        (b.include?("suit") && b.include?("jacket"))
    end

    def excluded_for_event?(g, type)
      EXCLUDED_SUBCATEGORIES[type]&.include?(sub_key(g))
    end

    def color_words(str)
      str.to_s.downcase.strip.split(/[\s,\/\-_]+/).to_set
    end

    def color_word_set(colors)
      colors.flat_map { color_words(_1) }.to_set
    end

    def color_score(g)
      words = color_words(g.color_primary) | color_words(g.color_secondary)
      return 0.0 if words.empty?

      score = 0.0
      score += COLOR_AVOID_PENALTY if @avoid_words.any? && !(words & @avoid_words).empty?
      score += COLOR_MATCH_BONUS if @fav_words.any? && !(words & @fav_words).empty?
      if @tone == "warm" && !(words & WARM_COLORS).empty?
        score += COLOR_TONE_BONUS
      elsif @tone == "cool" && !(words & COOL_COLORS).empty?
        score += COLOR_TONE_BONUS
      end
      score
    end

    def size_label(measurements)
      return nil unless measurements

      ref = measurements[:chest_cm] || measurements[:waist_cm]
      return nil unless ref

      case ref
      when ..82 then "xs"
      when ..86 then "s"
      when ..90 then "m"
      when ..96 then "l"
      when ..104 then "xl"
      else "xxl"
      end
    end

    def size_band_index(label)
      norm = label.to_s.strip.downcase
      SIZE_BANDS.index { _1.include?(norm) } || -1
    end

    def size_match?(g, label)
      return false if g.size.blank?

      g_band = size_band_index(g.size)
      u_band = size_band_index(label)
      g_band != -1 && u_band != -1 && g_band == u_band
    end

    def apply_gender_filter(garments)
      gender = @context.gender&.to_s&.downcase
      opposite = case gender
      when "male" then "women"
      when "female" then "men"
      end
      return garments unless opposite

      garments.reject { _1.gender == opposite }
    end

    def pick(pool, type_fn, chain, used:, event_type:, label:, extra: nil, tiebreak: nil, allow_reuse: true)
      candidates = pool.select do |g|
        type_fn.call(g) && !excluded_for_event?(g, event_type) && (extra.nil? || extra.call(g))
      end
      return nil if candidates.empty?

      scores = candidates.index_with { color_score(_1) }
      candidates.sort_by! do |g|
        tb = tiebreak ? tiebreak.call(g) : 0
        [ @recently_worn.include?(g.id) ? 1 : 0, g.times_recommended, tb, -scores[g], g.id ]
      end

      tiers = chain.map(&:to_set) + [ :untagged ]
      tiers.each do |tier|
        subset = if tier == :untagged
          candidates.select { _1.formality.nil? }
        else
          candidates.select { _1.formality.present? && tier.include?(_1.formality) }
        end
        result = pick_from(subset, used:, label:, scores:, allow_reuse:)
        return result if result
      end
      nil
    end

    def pick_from(subset, used:, label:, scores:, allow_reuse:)
      return nil if subset.empty?

      if allow_reuse
        unused = subset.reject { used.include?(_1.id) }
        in_use = subset.select { used.include?(_1.id) }
        best(unused, label:, scores:) || best(in_use, label:, scores:)
      else
        best(subset.reject { used.include?(_1.id) }, label:, scores:)
      end
    end

    def best(items, label:, scores:)
      return nil if items.empty?

      if label
        sized_clean = items.select { size_match?(_1, label) && scores[_1] >= 0 }
        return sized_clean.first if sized_clean.any?

        sized_any = items.select { size_match?(_1, label) }
        return sized_any.first if sized_any.any?
      end

      not_avoided = items.select { scores[_1] >= 0 }
      return not_avoided.first if not_avoided.any?

      items.first
    end

    def pick_outerwear(pool, top:, displayed:, day_index:)
      return nil unless OUTERWEAR_EVENTS.include?(displayed)
      return nil if top && STRUCTURED_TOP_RE.match?(blob(top))

      outer = pool.select { _1.category == "outerwear" }
      return nil if outer.empty?

      if top && (structured_jacket?(top) || STRUCTURED_TOP_RE.match?(blob(top)))
        filtered = outer.reject { structured_jacket?(_1) || blob(_1).include?("blazer") }
        outer = filtered unless filtered.empty?
      end

      sorted = outer.sort_by { [ _1.times_recommended, _1.id ] }
      sorted[day_index % sorted.size]
    end

    def pick_shoes(pool, type:, chain:, label:, used:)
      shoe_pool = pool.select { _1.category == "shoes" }
      return nil if shoe_pool.empty?

      if type == "gym"
        casual = shoe_pool.reject { DRESS_SHOE_RE.match?(blob(_1)) }
        return (casual.first || shoe_pool.min_by { [ _1.times_recommended, _1.id ] })
      end

      picked = pick(shoe_pool, ->(g) { g.category == "shoes" }, chain, used:, event_type: type, label:)
      picked || shoe_pool.min_by { [ _1.times_recommended, _1.id ] }
    end
  end
end
