# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    time_zone { "America/New_York" }

    trait :new_user do
      onboarding_completed_at { nil }
      onboarding_step { 0 }
    end

    trait :onboarded do
      onboarding_completed_at { Time.current }
      onboarding_step { 4 }
    end

    trait :onboarded_step_4 do
      onboarding_step { 4 }
      onboarding_completed_at { nil }
    end

    trait :with_profile do
      after(:create) do |user|
        user.profile.update!(gender: "female", color_tone: "warm", favorite_colors: %w[navy])
      end
    end

    trait :with_measurements do
      after(:create) do |user|
        create(:body_measurement, user: user, height_cm: 170, weight_kg: 65)
      end
    end

    trait :with_colors do
      after(:create) do |user|
        user.profile.update!(favorite_colors: %w[blue], avoided_colors: %w[orange])
      end
    end

    trait :with_google do
      provider { "google_oauth2" }
      sequence(:uid) { |n| "google-uid-#{n}" }
      google_access_token { "encrypted-access" }
      google_refresh_token { "encrypted-refresh" }
      google_token_expires_at { 1.hour.from_now }
    end
  end

  factory :user_profile do
    user
  end

  factory :body_measurement do
    user
    height_cm { 175.0 }
    weight_kg { 70.0 }
  end

  factory :ai_call do
    kind { "outfit_explanation" }
    status { "ok" }
    est_cost_cents { 10 }
  end

  # The :garment factory lives in spec/factories/garments.rb (Phase 2).
end
