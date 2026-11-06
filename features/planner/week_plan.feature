Feature: Weekly Outfit Planning
  As an onboarded user
  I want to view and generate a weekly outfit plan
  So that I know what to wear each day

  Background:
    Given I am signed in as an onboarded user

  Scenario: Generating a week plan
    Given my wardrobe contains:
      | name               | category | formality | color | hidden |
      | White Oxford Shirt | top      | business  | white | false  |
      | Navy Chinos        | bottom   | business  | navy  | false  |
      | Brown Loafers      | shoes    | business  | brown | false  |
    When I visit "/week_plan"
    Then I should see "Week Plan"
