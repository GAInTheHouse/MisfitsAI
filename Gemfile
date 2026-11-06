source "https://rubygems.org"

gem "rails", "~> 8.0.5", ">= 8.0.5.2"
gem "json", "~> 2.7"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"

gem "devise"
gem "omniauth-google-oauth2"
gem "omniauth-rails_csrf_protection"

gem "googleauth"
gem "google-apis-calendar_v3"
gem "google-analytics-data-v1beta"
gem "google-cloud-storage"

gem "faraday"
gem "faraday-retry"
gem "faraday-multipart"

gem "ssrf_filter"
gem "image_processing"
gem "ruby-vips", require: false
gem "pdf-reader"
gem "rack-attack"

gem "tzinfo-data", platforms: %i[windows jruby]

gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "bundler-audit", require: false
  gem "dotenv-rails"
end

group :development do
  gem "web-console"
end

group :test do
  gem "cucumber-rails", require: false
  gem "capybara"
  gem "cuprite"
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "webmock"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  gem "simplecov", require: false
  gem "climate_control"
end
