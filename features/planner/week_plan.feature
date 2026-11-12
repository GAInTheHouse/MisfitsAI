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

  Scenario: The guard links to the wardrobe
    When I visit "/week_plan"
    And I generate outfits for my week
    Then I should see a link "Go to your wardrobe" to the wardrobe page

  Scenario: The week follows the user's time zone
    Given my time zone is "Pacific/Auckland"
    And today is "2026-10-25T20:00:00Z"
    When I visit "/week_plan"
    Then the week plan should start on Monday "Oct 26" and end on Sunday "Nov 1"

  @javascript
  Scenario: Clicking a pill saves that day
    Given my week is:
      | day       | event_type |
      | Wednesday | none       |
    When I visit "/week_plan"
    And I pick "Gym" for Wednesday
    Then Wednesday should be saved as "gym"
    And my week plan source should be "manual"
