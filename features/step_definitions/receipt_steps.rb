# frozen_string_literal: true

# Phase 2 receipt steps (design doc 6.12, 8.3). The AI is always Ai::Client::Fake.

Given("the AI will read these items from my receipt image:") do |table|
  items = table.hashes.map do |row|
    row.transform_values(&:presence).merge(
      "price" => row["price"].presence&.to_f, "confidence" => row["confidence"].presence&.to_f
    )
  end
  Ai::Client::Fake.stub(:receipt_extraction, { "items" => items })
end

When("I paste this receipt text:") do |text|
  submit_receipt { fill_in "Paste receipt or order email text", with: text }
end

When("I upload the receipt {string}") do |filename|
  submit_receipt { attach_file "Receipt file", Rails.root.join("spec/fixtures/files", filename).to_s }
end

When("I upload an {int} MB receipt file") do |megabytes|
  file = Tempfile.new([ "large-receipt", ".pdf" ])
  file.binmode
  file.write("%PDF-1.4\n")
  file.write("0" * (megabytes * 1024 * 1024))
  file.close
  submit_receipt { attach_file "Receipt file", file.path }
end

When("I exclude the receipt row {string}") do |name|
  within(receipt_row_css(name)) { uncheck("Include") }
end

Then("I should see {int} receipt row(s)") do |count|
  expect(page).to have_css("article.receipt-row", count: count)
end

Then("I should see a receipt row for {string} with price {string}") do |name, price|
  within(receipt_row_css(name)) { expect(page).to have_field("Price", with: price) }
end

Then("I should not see a receipt row for {string}") do |name|
  expect(page).to have_no_css(receipt_row_css(name))
end

Then("the receipt row {string} should be flagged {string}") do |name, flag|
  within(receipt_row_css(name)) { expect(page).to have_content(flag) }
end
