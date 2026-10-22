# frozen_string_literal: true

require Rails.root.join("db/seeds/demo_user").to_s
require Rails.root.join("db/seeds/demo_wardrobe").to_s

user = DemoUser.seed
if user.nil?
  puts "Demo user skipped: set DEMO_PASSWORD to create #{DemoUser::EMAIL} in production"
  return
end

puts "Demo user: #{user.email} (password from DEMO_PASSWORD)"

# --- Phase 2: demo wardrobe (design doc 9.4) ---
garments = DemoWardrobe.seed(user)
puts "Demo wardrobe: #{garments.size} garments (#{user.garments.count} in total)"
