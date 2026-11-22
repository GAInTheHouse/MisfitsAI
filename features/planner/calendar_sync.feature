Feature: Google Calendar sync
  As a user with a busy calendar
  I want my week's events imported automatically
  So that outfits match what I'm actually doing

  Background:
    Given today is "2026-10-19 12:00"

  Scenario: Connecting without tokens goes through Google and syncs on return
    Given I am signed in as an onboarded user
    And Google will connect the calendar account "me.calendar@gmail.com"
    And my Google calendar has these events:
      | date       | summary         |
      | 2026-10-19 | Sprint planning |
    When I connect my Google Calendar
    Then I should be back on the week plan page
    And I should see "Google Calendar connected. Syncing your week…"
    And my account should be linked to the Google account "me.calendar@gmail.com"
    When background jobs finish
    Then my week should be:
      | day    | event_type   | summary         |
      | Monday | work_meeting | Sprint planning |
    And I should see "Sprint planning"
    And I should see "Sync again"

  Scenario: Events are classified and the busiest type wins per day
    Given I am signed in as an onboarded user with Google connected
    And my Google calendar has these events:
      | date       | summary            |
      | 2026-10-19 | Sprint planning    |
      | 2026-10-19 | Yoga class         |
      | 2026-10-20 | Call Mom           |
      | 2026-10-23 | Anniversary dinner |
    When I sync my calendar
    And background jobs finish
    Then my week should be:
      | day       | event_type   | summary            |
      | Monday    | work_meeting | Sprint planning    |
      | Tuesday   | casual       | Call Mom           |
      | Wednesday | none         |                    |
      | Friday    | date_night   | Anniversary dinner |

  Scenario: Same-day priority keeps the higher type, and the first event on a tie
    Given I am signed in as an onboarded user with Google connected
    And my Google calendar has these events:
      | date       | summary          | time    |
      | 2026-10-21 | Morning run      | 07:00   |
      | 2026-10-21 | Client lunch     | 12:00   |
      | 2026-10-22 | Team standup     | 09:00   |
      | 2026-10-22 | Design review    | 15:00   |
      | 2026-10-24 | Farmers market   | all day |
      | 2026-10-24 | Date night out   | 19:00   |
    When I sync my calendar
    And background jobs finish
    Then my week should be:
      | day       | event_type   | summary        |
      | Wednesday | work_meeting | Client lunch   |
      | Thursday  | work_meeting | Team standup   |
      | Saturday  | date_night   | Date night out |

  Scenario: Days with no events become "No major event"
    Given I am signed in as an onboarded user with Google connected
    And my week is:
      | day    | event_type |
      | Sunday | gym        |
    And my Google calendar has these events:
      | date       | summary         |
      | 2026-10-19 | Sprint planning |
    When I sync my calendar
    And background jobs finish
    Then my week should be:
      | day       | event_type |
      | Tuesday   | none       |
      | Sunday    | none       |

  Scenario: An expired Google connection prompts a reconnect
    Given I am signed in as an onboarded user with Google connected
    And my Google access has been revoked
    When I sync my calendar
    And background jobs finish
    Then I should see "Your Google connection expired. Please reconnect."
    And I should see "Connect Google Calendar"
    And my Google tokens should be cleared
