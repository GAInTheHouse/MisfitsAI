Feature: Add a garment manually
  As a user digitising my closet
  I want to describe a garment and save it
  So that it can be used in my outfit plans

  # Design doc 6.4 (Manual add, GenerateGarmentImageJob).
  # Every scenario is @wip until Phase 2 Steps 4-5 implement it.

  Background:
    Given I am signed in as an onboarded user
    And I am on the wardrobe page

  @wip
  Scenario: Add a garment with a generated product image
    When I fill in "Name" with "White Oxford Shirt"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then my wardrobe should contain "White Oxford Shirt"
    And the garment "White Oxford Shirt" should use a placeholder image
    When background jobs finish
    Then the garment "White Oxford Shirt" should have a generated image

  @wip
  Scenario: Add a garment without generating an image
    When I fill in "Name" with "Navy Chinos"
    And I choose the category "Bottom"
    And I uncheck "Generate a product image"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Navy Chinos"
    And the garment "Navy Chinos" should use a placeholder image
    And no AI image generation should have been requested

  @wip
  Scenario: Formality and season default to casual and all-season
    When I fill in "Name" with "Grey Hoodie"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then the garment "Grey Hoodie" should have formality "casual" and season "all_season"

  @wip
  Scenario: A name is required
    When I choose the category "Top"
    And I click "Add to wardrobe"
    Then I should see "Name can't be blank"
    And my wardrobe should be empty

  @wip
  Scenario: A name longer than 80 characters is rejected
    When I fill in "Name" with a name of 81 characters
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then I should see "Name is too long (maximum is 80 characters)"
    And my wardrobe should be empty

  @wip
  Scenario: A category is required
    When I fill in "Name" with "Mystery Item"
    And I click "Add to wardrobe"
    Then I should see "Category can't be blank"
    And my wardrobe should be empty

  @wip
  Scenario: Image generation disabled falls back to the placeholder
    Given AI image generation is disabled
    When I fill in "Name" with "Black Blazer"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Black Blazer"
    And the garment "Black Blazer" should use a placeholder image

  @wip
  Scenario: A blocked image falls back to the placeholder
    Given the AI blocks images for "garment_image"
    When I fill in "Name" with "Red Midi Dress"
    And I choose the category "Dress"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Red Midi Dress"
    And the garment "Red Midi Dress" should use a placeholder image
