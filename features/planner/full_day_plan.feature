Feature: Full-day outfit planning
  As someone with several different events in one day
  I want an outfit for each part of my day, and to know when to change
  So that I'm dressed right from the morning workout to the evening dinner

  # Issue #8. Events come from the stubbed Google Calendar (features/support/stubs/google.rb).

  Background:
    Given today is "2026-10-19 06:00"
    And I am signed in as an onboarded user with Google connected
    And my wardrobe contains:
      | name               | category | formality    | color | sub_category |
      | Gym Tee            | top      | casual       | gray  | t_shirt      |
      | White Oxford Shirt | top      | business     | white | shirt        |
      | Leggings           | bottom   | casual       | black | leggings     |
      | Black Dress Pants  | bottom   | business     | black | dress_pants  |
      | White Sneakers     | shoes    | casual       | white | sneakers     |

  Scenario: A gym session and a work meeting get separate outfits and a change note
    Given my Google calendar has these events:
      | date       | summary         | time  |
      | 2026-10-19 | Morning run     | 07:00 |
      | 2026-10-19 | Sprint planning | 10:00 |
    When I sync my calendar
    And background jobs finish
    Then I should see "Morning run"
    And I should see "Sprint planning"
    When I generate outfits for my week
    And I open today's outfits
    Then I should see "Today's outfits"
    And I should see 2 outfits on the timeline
    And outfit 1 on the timeline should include "Gym Tee"
    And outfit 2 on the timeline should include "White Oxford Shirt"
    And outfit 2 on the timeline should say "Change after your workout: gym pieces don't suit Sprint planning at 10:00 AM."

  Scenario: Events that fit one outfit stay as one outfit
    Given my Google calendar has these events:
      | date       | summary         | time  |
      | 2026-10-19 | Team standup    | 09:00 |
      | 2026-10-19 | Client review   | 14:00 |
    When I sync my calendar
    And I generate outfits for my week
    And I open today's outfits
    Then I should see 1 outfit on the timeline
    And outfit 1 on the timeline should include "White Oxford Shirt"

  Scenario: Confirming what I wore keeps that day when I regenerate
    Given my Google calendar has these events:
      | date       | summary         | time  |
      | 2026-10-19 | Morning run     | 07:00 |
      | 2026-10-19 | Sprint planning | 10:00 |
    When I sync my calendar
    And I generate outfits for my week
    And I open today's outfits
    And I mark outfit 1 on the timeline as worn
    Then outfit 1 on the timeline should say "Worn ✓ (undo)"
    When I generate outfits for my week
    And I open today's outfits
    Then outfit 1 on the timeline should say "Worn ✓ (undo)"
    And I should see 2 outfits on the timeline

  Scenario: Days without a plan point back to the calendar
    When I open today's outfits
    Then I should see "Plan your week first."
