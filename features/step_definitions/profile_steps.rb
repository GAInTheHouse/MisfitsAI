# frozen_string_literal: true

Given("I visit {string}") do |path|
  visit path
end

When("I choose gender {string} in the personal section") do |gender|
  within "#profile_personal" do
    choose gender
  end
end

When("I click {string} in the personal section") do |label|
  within "#profile_personal" do
    click_button label
  end
end

When("I click {string} in the measurements section") do |label|
  within "#profile_measurements" do
    click_button label
  end
end

When("I click {string} in the style section") do |label|
  within "#profile_style" do
    click_button label
  end
end

When("I click {string} in the sizes section") do |label|
  within "#profile_sizes" do
    click_button label
  end
end

When("I select {string} as both a favorite and an avoided color") do |color|
  within "#profile_style" do
    check "#{color} (favorite)"
    check "#{color} (avoided)"
  end
end

When("I select {string} as my top size") do |size|
  within "#profile_sizes" do
    choose "top_size_#{size.downcase}"
  end
end

When("I select {string} as my bottom size") do |size|
  within "#profile_sizes" do
    choose "bottom_size_#{size.downcase}"
  end
end

When("I change the {string} field to {string}") do |field, value|
  choose value if field == "Gender"
end

Then("I should see the Save bar") do
  expect(page).to have_css("[data-dirty-form-target='bar']:not([hidden])")
end

Then("the {string} field should be reverted") do |_field|
  expect(page).not_to have_css("[data-dirty-form-target='bar']:not([hidden])")
end
