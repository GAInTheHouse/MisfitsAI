#!/usr/bin/env ruby
# frozen_string_literal: true

# Merges SimpleCov result sets (e.g. RSpec + Cucumber) and prints the headline line rate.
# Usage: bundle exec ruby script/collate_coverage.rb coverage/rspec/.resultset.json coverage/cucumber/.resultset.json

require "simplecov"

paths = ARGV.empty? ? Dir.glob("coverage/**/.resultset.json") : ARGV
abort "No coverage result sets found in #{paths.inspect}" if paths.empty?

SimpleCov.collate(paths) do
  command_name "Merged"
  merge_timeout 3600
  skip "/spec/"
  skip "/features/"
  skip "/test/"
  group "Services", "app/services"
  group "Jobs", "app/jobs"
  group "Controllers", "app/controllers"
  group "Models", "app/models"
end

SimpleCov.result.format!
result = SimpleCov.result
pct = format("%.2f", result.covered_percent)
puts "Merged line coverage: #{result.covered_lines} / #{result.total_lines} (#{pct}%)"
