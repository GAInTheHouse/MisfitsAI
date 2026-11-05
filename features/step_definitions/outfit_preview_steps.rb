# frozen_string_literal: true

Then("the {string} stepper step should be complete") do |step_name|
  expect(page).to have_css("[data-stepper-step='#{step_name.downcase}'][data-complete='true']")
end

Then("I should see the mobile tab bar") do
  expect(page).to have_css("nav.md\\:hidden")
end
