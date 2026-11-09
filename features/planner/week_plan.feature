Feature: Weekly Outfit Planning
  As an onboarded user
  I want to view and generate a weekly outfit plan
  So that I know what to wear each day

  Background:
    Given I am signed in as an onboarded user

  Scenario: Week plan page shows seven days
    When I visit "/week_plan"
    Then I should see "Week Plan"
    And I should see "Monday"
    And I should see "Sunday"

  Scenario: Demo week and generate outfits
    Given my wardrobe contains:
      | name               | category | formality | color | hidden |
      | White Oxford Shirt | top      | business  | white | false  |
      | Navy Chinos        | bottom   | business  | navy  | false  |
      | Brown Loafers      | shoes    | business  | brown | false  |
    When I visit "/week_plan"
    And I apply the demo week
    And I generate outfits for my week
    Then I should see "Your Outfits"
    And I should see 7 day cards

  Scenario: Generate is blocked without enough garments
    When I visit "/week_plan"
    And I generate outfits for my week
    Then I should see "Add at least one top and one bottom"
