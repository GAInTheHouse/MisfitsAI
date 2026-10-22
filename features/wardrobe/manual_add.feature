Feature: Add a garment manually
  As a user digitising my closet
  I want to describe a garment and save it
  So that it can be used in my outfit plans

  # Design doc 6.4 (Manual add, GenerateGarmentImageJob).
  # AI image generation uses the fake adapter (features/support/ai_fake.rb).

  Background:
    Given I am signed in as an onboarded user
    And I am on the wardrobe page

  Scenario: Add a garment with a generated product image
    When I fill in "Name" with "White Oxford Shirt"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then my wardrobe should contain "White Oxford Shirt"
    And the garment "White Oxford Shirt" should use a placeholder image
    When background jobs finish
    Then the garment "White Oxford Shirt" should have a generated image

  Scenario: Add a garment without generating an image
    When I fill in "Name" with "Navy Chinos"
    And I choose the category "Bottom"
    And I uncheck "Generate a product image"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Navy Chinos"
    And the garment "Navy Chinos" should use a placeholder image
    And no AI image generation should have been requested

  Scenario: Formality and season default to casual and all-season
    When I fill in "Name" with "Grey Hoodie"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then the garment "Grey Hoodie" should have formality "casual" and season "all_season"

  Scenario: A name is required
    When I choose the category "Top"
    And I click "Add to wardrobe"
    Then I should see "Name can't be blank"
    And my wardrobe should be empty

  Scenario: A name longer than 80 characters is rejected
    When I fill in "Name" with a name of 81 characters
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then I should see "Name is too long (maximum is 80 characters)"
    And my wardrobe should be empty

  Scenario: A category is required
    When I fill in "Name" with "Mystery Item"
    And I click "Add to wardrobe"
    Then I should see "Category can't be blank"
    And my wardrobe should be empty

  @javascript
  Scenario: A new garment appears without reloading the page
    When I fill in "Name" with "Linen Shirt"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    Then I should see the garment "Linen Shirt"
    And I should see "Added Linen Shirt to your wardrobe."
    And the wardrobe count should be 1
    And the "Name" field should be empty
    And my wardrobe should contain "Linen Shirt"

  Scenario: Image generation disabled falls back to the placeholder
    Given AI image generation is disabled
    When I fill in "Name" with "Black Blazer"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Black Blazer"
    And the garment "Black Blazer" should use a placeholder image

  Scenario: A blocked image falls back to the placeholder
    Given the AI blocks images for "garment_image"
    When I fill in "Name" with "Red Midi Dress"
    And I choose the category "Dress"
    And I click "Add to wardrobe"
    And background jobs finish
    Then my wardrobe should contain "Red Midi Dress"
    And the garment "Red Midi Dress" should use a placeholder image

  @javascript
  Scenario: The generated image appears without reloading the page
    When I fill in "Name" with "Navy Peacoat"
    And I choose the category "Outerwear"
    And I click "Add to wardrobe"
    Then I should see the garment "Navy Peacoat"
    When background jobs finish
    Then the card for "Navy Peacoat" should update to its generated image

  Scenario: A failed image can be retried
    Given the AI service fails for "garment_image"
    When I fill in "Name" with "Grey Hoodie"
    And I choose the category "Top"
    And I click "Add to wardrobe"
    And background jobs finish
    And I am on the wardrobe page
    Then the garment "Grey Hoodie" should show the button "Retry image"
    When the AI service recovers for "garment_image"
    And I click "Retry image"
    And background jobs finish
    Then the garment "Grey Hoodie" should have a generated image
