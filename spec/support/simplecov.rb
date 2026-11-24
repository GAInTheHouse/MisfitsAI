# frozen_string_literal: true

return unless ENV["COVERAGE"]
return if defined?(SimpleCov) && SimpleCov.running

require "simplecov"

SimpleCov.start "rails" do
  command_name ENV.fetch("COVERAGE_COMMAND", "test")
  merge_timeout 3600

  skip "/spec/"
  skip "/features/"
  skip "/test/"
  skip "/vendor/"

  group "Services", "app/services"
  group "Jobs", "app/jobs"
  group "Controllers", "app/controllers"
  group "Models", "app/models"
  group "Channels", "app/channels"
end
