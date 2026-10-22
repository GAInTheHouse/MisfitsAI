# frozen_string_literal: true

FactoryBot.define do
  factory :garment do
    user
    sequence(:name) { |n| "Garment #{n}" }
    category { "top" }
    source { "manual" }
    # No image is attached by default, so the status says so; use :with_image for a "ready" garment.
    image_status { "placeholder" }

    Garment::CATEGORIES.each do |cat|
      trait(cat.to_sym) { category { cat } }
    end

    trait :hidden do
      hidden_from_recommendations { true }
    end

    trait :pending_image do
      image_status { "pending" }
    end

    trait :with_image do
      image_status { "ready" }
      after(:build) do |garment|
        garment.image.attach(
          io: File.open(Rails.root.join("spec/fixtures/files/garment.jpg")),
          filename: "garment.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end

  factory :intake_batch do
    user
    kind { "photo" }
    status { "processing" }

    trait :receipt do
      kind { "receipt" }
    end

    trait :ready do
      status { "ready" }
      progress { 100 }
    end

    trait :failed do
      status { "failed" }
      error { "We couldn't analyze that photo right now. Please try again." }
    end
  end

  factory :garment_draft do
    intake_batch
    user { intake_batch.user }
    status { "pending" }
    selected { true }
    sequence(:position)
    attrs { { "name" => "Crewneck Sweater", "category" => "top" } }

    trait :ready do
      status { "ready" }
    end

    trait :failed do
      status { "failed" }
      error { "Image generation failed" }
    end
  end
end
