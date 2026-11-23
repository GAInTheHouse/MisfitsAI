# frozen_string_literal: true

FactoryBot.define do
  factory :week_plan do
    association :user
    week_start { Planner::Week.current_start(user) }
    source { "manual" }
  end

  factory :week_event do
    association :week_plan
    date { Time.current.in_time_zone(week_plan.user.time_zone).to_date }
    event_type { "work_meeting" }
  end

  factory :outfit_recommendation do
    association :week_plan
    date { Time.current.in_time_zone(week_plan.user.time_zone).to_date }
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
