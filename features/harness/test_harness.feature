Feature: Phase 2 test harness
  As a developer
  I want the Cucumber harness itself to be checked
  So that acceptance scenarios fail only for real reasons

  # Checks the shared test infrastructure added in Phase 2 Step 2 (design doc 8.1-8.3).
  # Scenario order matters for the ENV sandbox check: Cucumber runs a file top to bottom.

  Scenario: Background jobs finish drains jobs enqueued by other jobs
    Given a chain of 4 background jobs is enqueued
    When background jobs finish
    Then all 4 chained jobs should have run
    And no background jobs should be enqueued

  Scenario: Cucumber always uses the fake AI adapter
    Then the AI adapter should be the fake adapter

  Scenario: A scenario can switch a feature and the image kill switch off
    Given the "photo_intake" feature is disabled
    And AI image generation is disabled
    Then the "photo_intake" feature should be off
    And AI image generation should be off

  Scenario: ENV changes from an earlier scenario do not leak
    Then the "photo_intake" feature should be on
    And AI image generation should be on

  Scenario: The AI can be told to block images for one kind
    Given the AI blocks images for "garment_image"
    Then generating a "garment_image" should be blocked

  Scenario: The canonical wardrobe table creates my garments
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality    | color | size | gender | hidden | times_recommended | sub_category |
      | White Oxford Shirt | top      | business     | white | M    |        | false  | 0                 | shirt        |
      | Red Midi Dress     | dress    | smart_casual | red   |      | women  | true   | 2                 |              |
    Then my garments should be:
      | name               | category | formality    | color_primary | size | gender | hidden_from_recommendations | times_recommended | sub_category | source | image_status |
      | Red Midi Dress     | dress    | smart_casual | red           |      | women  | true                        | 2                 |              | manual | placeholder  |
      | White Oxford Shirt | top      | business     | white         | M    |        | false                       | 0                 | shirt        | manual | placeholder  |
