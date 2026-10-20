# frozen_string_literal: true

# An empty DATABASE_URL in .env overrides database.yml and breaks local/test DB config.
ENV.delete("DATABASE_URL") if ENV["DATABASE_URL"].blank?
