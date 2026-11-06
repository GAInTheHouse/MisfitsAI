# frozen_string_literal: true

module Options
  class << self
    def fetch(key)
      data[key]
    end

    def data
      @data ||= YAML.load_file(Rails.root.join("config/options.yml"), aliases: true).with_indifferent_access
    end

    def reload!
      @data = nil
    end
  end
end
