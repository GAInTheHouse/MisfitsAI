Feature: Google sign in
  As a visitor
  I want to sign in with Google
  So that I can connect my calendar later

  @pre_onboarding
  Scenario: A new Google user is created
    Given Google OAuth returns a new user "google@example.com"
    When I post Google OAuth callback
    Then I should be on the wardrobe page

  Scenario: An existing email account gets linked
    Given a user exists with email "link@example.com"
    And Google OAuth returns provider uid for "link@example.com"
    When I post Google OAuth callback
    Then the user "link@example.com" should have Google linked

  Scenario: Cancelled consent shows a flash
    When Google OAuth fails
    Then I should see "Google sign-in was cancelled"

  Scenario: Tokens are stored encrypted
    Given Google OAuth returns a new user "secure@example.com"
    When I post Google OAuth callback
    Then Google tokens should be encrypted for "secure@example.com"
