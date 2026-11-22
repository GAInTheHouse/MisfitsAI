Feature: Laundry tracking and wear history
  As a user managing my wardrobe
  I want worn outfits to update garment wear counts and laundry status
  So that dirty clothes are excluded from outfit plans until I wash them

  Scenario: Confirming an outfit moves a single-wear top to laundry and washing restores it
    Given a signed-in user with a wardrobe of:
      | name         | category | formality |
      | White Oxford | top      | casual    |
      | Navy Chinos  | bottom   | casual    |
    And today has a planned casual outfit with "White Oxford" and "Navy Chinos"
    When I visit today's outfits and confirm wearing the outfit
    And I visit the wear history page
    Then I should see "White Oxford" in the laundry basket
    When I mark "White Oxford" as washed
    Then the laundry basket should be empty
