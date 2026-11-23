# frozen_string_literal: true

When("I choose gender {string} in the personal section") do |gender|
  within "#profile_personal" do
    choose gender, allow_label_click: true
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
    find("input[name='user_profile[favorite_colors][]'][value='#{color.downcase}']", visible: :any).trigger("click")
    find("input[name='user_profile[avoided_colors][]'][value='#{color.downcase}']", visible: :any).trigger("click")
  end
end

When("I select {string} as my top size") do |size|
  within "#profile_sizes" do
    choose "top_size_#{size.downcase}", allow_label_click: true
  end
end

When("I select {string} as my bottom size") do |size|
  within "#profile_sizes" do
    choose "bottom_size_#{size.downcase}", allow_label_click: true
  end
end

When("I change the {string} field to {string}") do |field, value|
  choose value, allow_label_click: true if field == "Gender"
end

Then("I should see the Save bar") do
  expect(page).to have_css("[data-shared--dirty-form-target='bar']:not([hidden])")
end

Then("the {string} field should be reverted") do |_field|
  expect(page).not_to have_css("[data-shared--dirty-form-target='bar']:not([hidden])")
end

When("I click the {string} skin tone swatch") do |label|
  within "#profile_style" do
    find("label[title='#{label}'] .swatch").click
  end
end

Then("the {string} skin tone swatch should be highlighted before saving") do |label|
  within "#profile_style" do
    swatch = find("label[title='#{label}'] .swatch")
    expect(swatch.evaluate_script("getComputedStyle(this).borderColor")).to eq("rgb(27, 27, 25)")
  end
end

Then("the {string} skin tone swatch should not be highlighted") do |label|
  within "#profile_style" do
    swatch = find("label[title='#{label}'] .swatch")
    expect(swatch.evaluate_script("getComputedStyle(this).borderColor")).to eq("rgb(217, 217, 212)")
  end
end

When("I click the {string} favorite color swatch") do |color|
  within "#profile_style" do
    find("label[title='#{color} (favorite)'] .swatch").click
  end
end

Then("the {string} favorite color swatch should be highlighted before saving") do |color|
  within "#profile_style" do
    swatch = find("label[title='#{color} (favorite)'] .swatch")
    expect(swatch.evaluate_script("getComputedStyle(this).borderColor")).to eq("rgb(27, 27, 25)")
  end
end

Then("the {string} favorite color swatch should not be highlighted") do |color|
  within "#profile_style" do
    swatch = find("label[title='#{color} (favorite)'] .swatch")
    expect(swatch.evaluate_script("getComputedStyle(this).borderColor")).to eq("rgb(217, 217, 212)")
  end
end

When("I click the {string} avoided color swatch") do |color|
  within "#profile_style" do
    find("label[title='#{color} (avoided)'] .swatch").click
  end
end

Then("the {string} avoided color swatch should be highlighted before saving") do |color|
  within "#profile_style" do
    swatch = find("label[title='#{color} (avoided)'] .swatch")
    expect(swatch.evaluate_script("getComputedStyle(this).borderColor")).to eq("rgb(27, 27, 25)")
  end
end
