# frozen_string_literal: true

module Options
  class << self
    def fetch(key)
      data[key.to_s] || data[key.to_sym]
    end

    def data
      @data ||= YAML.load_file(Rails.root.join("config/options.yml"), aliases: true).deep_symbolize_keys
    end

    def reload!
      @data = nil
    end
  end
end
