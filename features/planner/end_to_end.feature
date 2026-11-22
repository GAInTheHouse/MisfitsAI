Feature: Plan a week from a wardrobe built by hand
  As a new user
  I want to add a few pieces and plan my week straight away
  So that I get outfits without any setup beyond my own clothes

  # Cross-phase (design doc 8.1, 11.3 task 1): garments come from Phase 2's real manual-add form,
  # not from a factory, and run through the real Phase 3 planner.

  Scenario: Add a top, a bottom and shoes, apply the demo week, and see 7 outfits
    Given I am signed in as an onboarded user
    And I am on the wardrobe page
    When I fill in "Name" with "White Tee"
    And I choose the category "Top"
    And I uncheck "Generate a product image"
    And I click "Add to wardrobe"
    And I fill in "Name" with "Blue Jeans"
    And I choose the category "Bottom"
    And I uncheck "Generate a product image"
    And I click "Add to wardrobe"
    And I fill in "Name" with "White Sneakers"
    And I choose the category "Shoes"
    And I uncheck "Generate a product image"
    And I click "Add to wardrobe"
    Then the wardrobe count should be 3
    When I apply the demo week
    And I generate outfits for my week
    Then I should see "Your Outfits"
    And I should see 7 day cards
    And Saturday's outfit should include "White Tee"
    And Saturday's outfit should include "Blue Jeans"
    And Saturday's outfit should include "White Sneakers"
    When background jobs finish
    Then Saturday's card should show an explanation
