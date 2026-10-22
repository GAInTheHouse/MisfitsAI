# frozen_string_literal: true

# The demo user's 15-item wardrobe (design doc 9.4, Phase 2). Plain Ruby so both db/seeds.rb and
# script/generate_seed_images.rb can read it. Chosen so the Phase 3 demo week works: business pieces for work
# meetings, a dress for date night, gym-safe tops, bottoms and shoes, outerwear, and an accessory.
# shape and rgb only drive the generated image (db/seeds/images/<image>).
DEMO_WARDROBE_ITEMS = [
  { name: "White Oxford Shirt", category: "top", sub_category: "shirt", color_primary: "white", formality: "business",
    seasonality: "all_season", brand: "Uniqlo", size: "M", material: "cotton", shape: :top, rgb: [ 244, 244, 240 ] },
  { name: "Light Blue Button-down", category: "top", sub_category: "shirt", color_primary: "blue", formality: "smart_casual",
    seasonality: "all_season", brand: "J.Crew", size: "M", material: "cotton", shape: :top, rgb: [ 170, 196, 226 ] },
  { name: "Navy Crewneck Sweater", category: "top", sub_category: "sweater", color_primary: "navy", formality: "smart_casual",
    seasonality: "cold", brand: "Everlane", size: "M", material: "wool", shape: :top, rgb: [ 38, 52, 92 ] },
  { name: "Grey Performance Tee", category: "top", sub_category: "t_shirt", color_primary: "grey", formality: "casual",
    seasonality: "hot", brand: "Nike", size: "M", material: "polyester", shape: :top, rgb: [ 150, 152, 156 ] },
  { name: "Charcoal Dress Pants", category: "bottom", sub_category: "dress_pants", color_primary: "charcoal",
    formality: "business", seasonality: "all_season", brand: "Banana Republic", size: "32", material: "wool",
    shape: :bottom, rgb: [ 62, 64, 68 ] },
  { name: "Dark Wash Jeans", category: "bottom", sub_category: "jeans", color_primary: "blue", formality: "casual",
    seasonality: "all_season", brand: "Levi's", size: "32", material: "denim", shape: :bottom, rgb: [ 44, 66, 104 ] },
  { name: "Khaki Chinos", category: "bottom", sub_category: "chinos", color_primary: "khaki", formality: "smart_casual",
    seasonality: "mild", brand: "Gap", size: "32", material: "cotton", shape: :bottom, rgb: [ 196, 176, 132 ] },
  { name: "Black Running Shorts", category: "bottom", sub_category: "shorts", color_primary: "black", formality: "casual",
    seasonality: "hot", brand: "Adidas", size: "M", material: "polyester", shape: :shorts, rgb: [ 34, 34, 36 ] },
  { name: "Black Midi Dress", category: "dress", sub_category: "midi_dress", color_primary: "black",
    formality: "smart_casual", seasonality: "all_season", brand: "Zara", size: "S", material: "crepe", shape: :dress,
    rgb: [ 30, 30, 34 ] },
  { name: "Camel Wool Coat", category: "outerwear", sub_category: "coat", color_primary: "camel",
    formality: "smart_casual", seasonality: "cold", brand: "Mango", size: "M", material: "wool", shape: :outerwear,
    rgb: [ 193, 154, 107 ] },
  { name: "Denim Jacket", category: "outerwear", sub_category: "jacket", color_primary: "blue", formality: "casual",
    seasonality: "mild", brand: "Levi's", size: "M", material: "denim", shape: :outerwear, rgb: [ 92, 124, 168 ] },
  { name: "White Leather Sneakers", category: "shoes", sub_category: "sneakers", color_primary: "white",
    formality: "casual", seasonality: "all_season", brand: "Vans", size: "9", material: "leather", shape: :sneaker,
    rgb: [ 236, 236, 232 ] },
  { name: "Brown Leather Loafers", category: "shoes", sub_category: "loafers", color_primary: "brown",
    formality: "smart_casual", seasonality: "all_season", brand: "Madewell", size: "9", material: "leather",
    shape: :shoes, rgb: [ 112, 72, 44 ] },
  { name: "Black Running Shoes", category: "shoes", sub_category: "sneakers", color_primary: "black", formality: "casual",
    seasonality: "all_season", brand: "New Balance", size: "9", material: "mesh", shape: :sneaker, rgb: [ 40, 42, 46 ] },
  { name: "Black Leather Belt", category: "accessory", sub_category: "belt", color_primary: "black",
    formality: "smart_casual", seasonality: "all_season", brand: "Calvin Klein", size: "M", material: "leather",
    shape: :belt, rgb: [ 36, 34, 32 ] }
].each { |item| item[:image] = "#{item[:name].downcase.gsub(/[^a-z0-9]+/, '_').delete_suffix('_')}.jpg" }.freeze
