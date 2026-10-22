# frozen_string_literal: true

# Phase 2 photo-intake steps (design doc 6.6, 8.3). The AI is always Ai::Client::Fake.

Given("the AI will detect these garments in my photo:") do |table|
  items = table.hashes.map { |row| row.transform_values(&:presence) }
  Ai::Client::Fake.stub(:garment_extraction, { "items" => items })
end

Given("the AI will detect no garments in my photo") do
  Ai::Client::Fake.stub(:garment_extraction, { "items" => [] })
end

Given("the AI will detect {int} garments in my photo") do |count|
  items = Array.new(count) do |i|
    { "item_type" => "garment #{i + 1}", "color" => "black", "category" => "top", "formality" => "casual",
      "seasonality" => "all_season" }
  end
  Ai::Client::Fake.stub(:garment_extraction, { "items" => items })
end

When("I upload {string} on the Photo AI tab") do |filename|
  upload_photo(Rails.root.join("spec/fixtures/files", filename))
end

When("I upload a {int} MB photo on the Photo AI tab") do |megabytes|
  file = Tempfile.new([ "large-photo", ".jpg" ])
  file.binmode
  file.write("\xFF\xD8\xFF\xE0".b) # a JPEG signature, then padding past the limit
  file.write("\0" * (megabytes * 1024 * 1024))
  file.close
  upload_photo(file.path)
end

When("I upload a non-image file on the Photo AI tab") do
  upload_photo(Rails.root.join("spec/fixtures/files/not_an_image.txt"))
end

When("I deselect {string}") do |name|
  within(%(article.garment-draft[data-name="#{name}"])) { uncheck("Add this item") }
end

Then("I should see {int} draft garment(s)") do |count|
  expect(page).to have_css("article.garment-draft", count: count)
end

Then("the uploaded photo should not be kept") do
  batch = IntakeBatch.where(user: @user).order(:created_at).last
  expect(batch.source_file).not_to be_attached
  expect(ActiveStorage::Attachment.where(record_type: "IntakeBatch")).to be_empty
end

Then("no AI analysis should have been requested") do
  expect(Ai::Client::Fake.calls.select { _1[:kind] == "garment_extraction" }).to be_empty
end
