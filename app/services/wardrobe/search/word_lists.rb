# frozen_string_literal: true

module Wardrobe
  module Search
    # Word lists for FilterAndRank (design doc 6.5).
    #
    # [DEVIATION] The doc says to copy these verbatim from backend/garment_search_filter.py, which is not
    # available to this team. They are rebuilt from the doc's description of each list and make no claim to
    # match the original. Tokens are lowercase, 3+ characters (FilterAndRank.tokenize drops shorter ones);
    # tokens of 5 characters or fewer only match whole words.
    module WordLists
      # Removed from the required tokens: filler that says nothing about which garment is wanted.
      STOPWORDS = %w[
        the and for with from your you our new sale shop buy best online official store brand item items
        men mens man women womens woman unisex kids adult size sizes style styles fashion clothing clothes
        apparel wear outfit look product products photo image images picture studio background
      ].to_set.freeze

      # Signs a result is not a clean product photo of a garment: people and editorial shots, drawings,
      # and objects that share words with garments ("laptop" for "top", "phone case").
      NEGATIVE_WORDS = %w[
        model models wearing worn person people selfie celebrity runway catwalk streetstyle lookbook editorial
        outfitoftheday ootd influencer instagram tiktok youtube
        drawing sketch illustration cartoon clipart vector template mockup icon logo sticker poster wallpaper
        laptop notebook tablet phone iphone case cover keychain mug toy doll costume halloween
        sewing tutorial diy crochet meme
      ].to_set.freeze

      # Words common on apparel product pages; each one found adds a little to the score (capped).
      APPAREL_HINTS = %w[
        cotton wool linen denim silk cashmere leather suede knit fleece polyester nylon
        fit slim regular relaxed oversized tailored cropped stretch
        sleeve sleeves collar neck crew button buttons zip pocket pockets waist rise hem cuff lining
        garment menswear womenswear apparel clothing
      ].to_set.freeze

      # A result must mention one of these to count as a garment (the noun gate). Covers every kind in
      # design doc 12.3 plus common synonyms.
      GARMENT_NOUNS = %w[
        shirt shirts tshirt tee tees top tops blouse sweater sweaters jumper pullover cardigan hoodie hoody
        sweatshirt blazer vest waistcoat polo henley turtleneck bodysuit tank camisole flannel oxford
        jacket jackets coat coats parka trench peacoat puffer bomber fleece anorak windbreaker gilet
        jeans pants trousers trouser chinos chino shorts skirt skirts leggings sweatpants joggers culottes cargo
        dress dresses gown jumpsuit romper playsuit sundress
        shoe shoes sneaker sneakers trainer trainers boot boots heel heels pump pumps loafer loafers oxfords
        sandal sandals slide slides flats mule mules
        bag bags handbag tote backpack crossbody belt scarf hat beanie cap sunglasses watch socks tie
        necklace bracelet earrings
      ].to_set.freeze

      # Garment nouns that identify a category, used to fill in a missing category when a search result is
      # added (Phase 2 decision; the doc leaves it to "the form attributes").
      CATEGORY_BY_NOUN = {
        "top" => %w[shirt tshirt tee top blouse sweater jumper pullover cardigan hoodie hoody sweatshirt blazer
                    vest waistcoat polo henley turtleneck bodysuit tank camisole flannel],
        "bottom" => %w[jeans pants trousers trouser chinos chino shorts skirt leggings sweatpants joggers culottes],
        "dress" => %w[dress gown jumpsuit romper playsuit sundress],
        "outerwear" => %w[jacket coat parka trench peacoat puffer bomber anorak windbreaker gilet],
        "shoes" => %w[shoe shoes sneaker sneakers trainer trainers boot boots heel heels pump pumps loafer loafers
                      oxfords sandal sandals slide slides flats mule mules],
        "accessory" => %w[bag handbag tote backpack crossbody belt scarf hat beanie cap sunglasses watch socks tie
                          necklace bracelet earrings]
      }.freeze
    end
  end
end
