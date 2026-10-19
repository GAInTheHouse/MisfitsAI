# frozen_string_literal: true

class Feature
  class << self
    def enabled?(name)
      env_key = "FEATURE_#{name.to_s.upcase}"
      return ActiveModel::Type::Boolean.new.cast(ENV[env_key]) if ENV.key?(env_key)

      defaults.fetch(name.to_s, false)
    end

    def defaults
      path = Rails.root.join("config/features.yml")
      data = YAML.load_file(path, aliases: true)
      @defaults ||= data[Rails.env] || data["default"] || {}
    end
  end
end
