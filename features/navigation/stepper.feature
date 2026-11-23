Feature: Navigation stepper
  As a user setting up my wardrobe
  I want to see my progress
  So that I know what steps remain

  Background:
    Given the "onboarding" feature is enabled
    And I am signed in as a new user

  Scenario: Wardrobe step shows a check mark when it has a top and a bottom
    Given my wardrobe contains:
      | name              | category | formality | color |
      | White Oxford Shirt| top      | business  | white |
      | Black Dress Pants | bottom   | business  | black |
    When I visit "/wardrobe"
    Then the "Wardrobe" stepper step should be complete

  Scenario: Outfits step shows a check mark when recommendations exist
    Given I have outfit recommendations for this week
    When I visit "/wardrobe"
    Then the "Outfits" stepper step should be complete

  Scenario: Profile step is always shown as complete
    When I visit "/wardrobe"
    Then the "Profile" stepper step should be complete

  Scenario: Stepper is hidden after onboarding is complete
    Given I am signed in as an onboarded user
    When I visit "/wardrobe"
    Then the setup stepper should not be visible

  @mobile @javascript
  Scenario: Mobile tab bar is visible on narrow screens
    When I visit "/wardrobe"
    Then I should see the mobile tab bar
