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

FactoryBot.define do
  factory :calendar_event do
    association :week_event
    summary { "Standup" }
    event_type { "work_meeting" }
    starts_at { Time.current.change(hour: 9) }
    all_day { false }
    position { 0 }
  end
end
