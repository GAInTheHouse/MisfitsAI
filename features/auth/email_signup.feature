Feature: Email sign up
  As a new visitor
  I want to create an account with email
  So that I can save my wardrobe

  @pre_onboarding
  Scenario: Sign up with valid details lands on the wardrobe
    Given I am on the sign up page
    When I fill in "Email" with "newuser@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I click "Sign up"
    Then I should be on the wardrobe page

  Scenario: Password shorter than 8 characters is rejected
    Given I am on the sign up page
    When I fill in "Email" with "short@example.com"
    And I fill in "Password" with "short"
    And I fill in "Password confirmation" with "short"
    And I click "Sign up"
    Then I should see "Password is too short"

  Scenario: Duplicate email is rejected
    Given a user exists with email "taken@example.com"
    And I am on the sign up page
    When I fill in "Email" with "taken@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password123"
    And I click "Sign up"
    Then I should see "Email has already been taken"

  Scenario: Password confirmation mismatch
    Given I am on the sign up page
    When I fill in "Email" with "mismatch@example.com"
    And I fill in "Password" with "password123"
    And I fill in "Password confirmation" with "password124"
    And I click "Sign up"
    Then I should see "Password confirmation doesn't match"
