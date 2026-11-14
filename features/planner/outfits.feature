Feature: Weekly outfit recommendations
  As a busy professional
  I want one outfit suggested for each day of my week
  So that I don't have to decide what to wear every morning

  Background:
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality    | color | sub_category |
      | White Oxford Shirt | top      | business     | white | shirt        |
      | Gray Hoodie        | top      | casual       | gray  | hoodie       |
      | Black Dress Pants  | bottom   | business     | black | dress_pants  |
      | Blue Jeans         | bottom   | casual       | blue  | jeans        |
      | Red Midi Dress     | dress    | smart_casual | red   | dress        |
      | White Sneakers     | shoes    | casual       | white | sneakers     |
      | Brown Loafers      | shoes    | smart_casual | brown | loafers      |
    And my week is:
      | day       | event_type   |
      | Monday    | work_meeting |
      | Tuesday   | gym          |
      | Wednesday | date_night   |
      | Thursday  | casual       |
      | Friday    | none         |
      | Saturday  | casual       |
      | Sunday    | none         |

  Scenario: Work meetings get business pieces, never hoodies
    When I generate outfits for my week
    Then Monday's outfit should include "White Oxford Shirt"
    And Monday's outfit should include "Black Dress Pants"
    And Monday's outfit should not include "Gray Hoodie"

  Scenario: Date night prefers a dress
    When I generate outfits for my week
    Then Wednesday's outfit should be the dress "Red Midi Dress"

  Scenario: Gym day avoids dress shoes
    When I generate outfits for my week
    Then Tuesday's outfit should include "White Sneakers"
    And Tuesday's outfit should not include "Brown Loafers"

  Scenario: Explanations stream in after jobs run
    When I generate outfits for my week
    And background jobs finish
    Then Monday's card should show an explanation

  Scenario: Explanation falls back to a template when AI is down
    Given the AI service fails for "outfit_explanation"
    When I generate outfits for my week
    And background jobs finish
    Then Monday's card should show "we've put together the best available pieces from your wardrobe"

  Scenario: The On Me slot stays empty while its flag is off
    Given the "outfit_preview" feature is disabled
    When I generate outfits for my week
    Then I should see 7 day cards
    And I should not see "Generate look"

  Scenario: The On Me slot appears when its flag is on
    Given the "outfit_preview" feature is enabled
    When I generate outfits for my week
    Then I should see "Generate look"

  Scenario: Hide an item from an outfit removes it from recommendations
    When I generate outfits for my week
    And background jobs finish
    And I visit "/outfits"
    And I hide "White Oxford Shirt" from the outfit detail
    Then "White Oxford Shirt" should be hidden from recommendations

  Scenario: Regenerate week creates a new set of outfits
    When I generate outfits for my week
    And I regenerate the week
    Then I should see 7 day cards

  Scenario: Missing bottom shows a banner linking to wardrobe
    Given Monday has an outfit with no bottom
    When I visit "/outfits"
    Then I should see "Missing bottom"
    And I should see a link to "/wardrobe"
