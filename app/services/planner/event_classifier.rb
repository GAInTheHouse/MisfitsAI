# frozen_string_literal: true

module Planner
  module EventClassifier
    RULES = [
      {
        type: "gym",
        keywords: %w[gym workout fitness run running yoga crossfit pilates swim cycling hiit training]
      },
      {
        type: "work_meeting",
        keywords: %w[meeting standup stand-up interview client presentation conference 1:1 sprint review
                     scrum retro all-hands]
      },
      {
        type: "date_night",
        keywords: [ "date night", "romantic", "anniversary", "valentine" ]
      }
    ].freeze

    PRIORITY = {
      "work_meeting" => 3,
      "date_night" => 2,
      "gym" => 1,
      "casual" => 0
    }.freeze

    module_function

    def call(summary)
      text = summary.to_s.downcase
      RULES.each do |rule|
        rule[:keywords].each do |kw|
          return rule[:type] if text.include?(kw)
        end
      end
      "casual"
    end

    def priority(type)
      PRIORITY.fetch(type, 0)
    end
  end
end
