Feature: Outfit on me (avatar outfit preview)
  As a user with an avatar
  I want to see outfits on my avatar
  So that I can visualize how they look

  Background:
    Given I am signed in as an onboarded user

  Scenario: On Me tab is hidden without an avatar
    Given I have outfit recommendations for this week
    And I do not have an avatar
    When I visit "/outfits"
    Then I should not see the "On Me" toggle

  Scenario: Generate look attaches a preview image
    Given I have an avatar
    And I have outfit recommendations for this week
    When I generate a look for Monday's outfit
    And background jobs finish
    Then Monday's outfit should have a preview image

  Scenario: A cache hit makes no AI call
    Given I have an avatar
    And I have outfit recommendations for this week
    And Monday's outfit already has a preview with the current cache key
    When I generate a look for Monday's outfit
    Then no AI image call should be made

  Scenario: Collage is used when image generation is disabled
    Given I have an avatar
    And I have outfit recommendations for this week
    And AI image generation is disabled
    When I generate a look for Monday's outfit
    And background jobs finish
    Then Monday's preview strategy should be "collage"
