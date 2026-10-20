Feature: Email login
  As a returning user
  I want to sign in with email
  So that I can access my wardrobe

  Scenario: Onboarded user lands on the wardrobe
    Given I am signed in as an onboarded user
    When I visit "/wardrobe"
    Then I should see "Your closet is empty"

  Scenario: Wrong password
    Given a user exists with email "user@example.com" and password "password123"
    When I sign in as "user@example.com" with password "wrongpass"
    Then I should see "Invalid email or password"

  Scenario: Sign out
    Given I am signed in as an onboarded user
    When I visit "/wardrobe"
    And I click "Sign out"
    Then I should see "Welcome"
