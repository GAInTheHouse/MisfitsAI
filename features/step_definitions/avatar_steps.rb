# frozen_string_literal: true

Given("I do not have an avatar") do
  @user.profile.update!(avatar_status: "none")
end

Given("I have an avatar") do
  @user.profile.update!(avatar_status: "ready")
  # attach a valid 64x64 png as the avatar
  png = File.read(Rails.root.join("spec/fixtures/ai/avatar_portrait.png"), encoding: "binary")
  @user.profile.avatar.attach(io: StringIO.new(png), filename: "avatar.png", content_type: "image/png")
end

When("I upload {string} as my avatar selfie") do |filename|
  path = Rails.root.join("spec/fixtures/files/#{filename}")
  path = Rails.root.join("spec/fixtures/files/outfit.jpg") unless File.exist?(path)
  within "#profile_avatar" do
    attach_file "Selfie", path
    click_button "Generate avatar"
  end
end

When("I upload an oversized file as my avatar selfie") do
  # generate in-memory > 15 MB
  large = StringIO.new("x" * (16 * 1024 * 1024))
  large.rewind
  large_path = Tempfile.new([ "oversized", ".jpg" ]).tap do |f|
    f.write(large.read)
    f.flush
  end.path
  within "#profile_avatar" do
    attach_file "Selfie", large_path
    click_button "Generate avatar"
  end
end

Then("I should see my avatar image") do
  expect(page).to have_css("img[data-avatar-image]")
end

Then("the selfie should not be stored") do
  @user.profile.reload
  expect(@user.profile.pending_selfie.attached?).to be false
end

Then("I should not see the {string} toggle") do |label|
  expect(page).not_to have_content(label)
end

Given("I have outfit recommendations for this week") do
  plan = @user.week_plans.create!(week_start: Date.current.beginning_of_week(:monday), source: "demo")
  7.times do |i|
    plan.week_events.create!(date: Date.current.beginning_of_week(:monday) + i, event_type: "casual")
    plan.outfit_recommendations.create!(date: Date.current.beginning_of_week(:monday) + i, event_type: "casual", explanation_status: "ready", preview_status: "none")
  end
end

When("I generate a look for Monday's outfit") do
  rec = @user.week_plans.first.outfit_recommendations.order(:date).first
  page.driver.browser.post(outfit_previews_path(outfit_id: rec.id))
  page.driver.browser.follow_redirect! if page.driver.browser.last_response.redirect?
end

Then("Monday's outfit should have a preview image") do
  rec = @user.week_plans.first.outfit_recommendations.order(:date).first.reload
  expect(rec.preview_status).to eq("ready")
end

Given("Monday's outfit already has a preview with the current cache key") do
  rec = @user.week_plans.first.outfit_recommendations.order(:date).first
  png = File.read(Rails.root.join("spec/fixtures/ai/outfit_preview_gemini.png"), encoding: "binary")
  rec.preview_image.attach(io: StringIO.new(png), filename: "preview.png", content_type: "image/png")
  avatar_check = @user.profile.avatar.attached? ? @user.profile.avatar.blob.checksum : "none"
  key = Digest::SHA256.hexdigest([ avatar_check, *rec.garments_in_display_order.map(&:id) ].join(":"))
  rec.update!(preview_status: "ready", preview_cache_key: key)
end

Then("no AI image call should be made") do
  expect(Ai::Client::Fake.calls.count { |c| c[:method] == :generate_image_with_subject || c[:method] == :generate_image_multimodal }).to eq(0)
end

Then("Monday's preview strategy should be {string}") do |strategy|
  rec = @user.week_plans.first.outfit_recommendations.order(:date).first.reload
  expect(rec.preview_strategy).to eq(strategy)
end
