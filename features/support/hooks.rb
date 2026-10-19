# frozen_string_literal: true

Before("@javascript") do
  Capybara.current_driver = :cuprite
end

After("@javascript") do
  Capybara.use_default_driver
end
