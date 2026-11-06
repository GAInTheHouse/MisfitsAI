# frozen_string_literal: true

FactoryBot.define do
  factory :week_plan do
    association :user
    week_start { Date.current.beginning_of_week(:monday) }
    source { "manual" }
  end

  factory :week_event do
    association :week_plan
    date { Date.current }
    event_type { "work_meeting" }
  end

  factory :outfit_recommendation do
    association :week_plan
    date { Date.current }
    event_type { "work_meeting" }
    explanation_status { "pending" }
    preview_status { "none" }
  end
end
