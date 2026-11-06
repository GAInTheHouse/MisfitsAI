Feature: Profile
  As a signed-in user
  I want to manage my style profile
  So that outfit recommendations match my preferences

  Background:
    Given I am signed in as an onboarded user

  @javascript
  Scenario: Save personal section
    Given I visit "/profile"
    When I choose gender "Female" in the personal section
    And I click "Save" in the personal section
    Then I should see "Saved"

  @javascript
  Scenario: Save measurements
    Given I visit "/profile"
    When I fill in "Height (cm)" with "170"
    And I fill in "Weight (kg)" with "65"
    And I click "Save" in the measurements section
    Then I should see "Saved"

  @javascript
  Scenario: A color cannot be both favorite and avoided
    Given I visit "/profile"
    When I select "Navy" as both a favorite and an avoided color
    And I click "Save" in the style section
    Then I should see "A color can't be both favorite and avoided"

  @javascript
  Scenario: Save sizes
    Given I visit "/profile"
    When I select "M" as my top size
    And I select "M" as my bottom size
    And I click "Save" in the sizes section
    Then I should see "Saved"

  @javascript
  Scenario: Discard reverts changes
    Given I visit "/profile"
    When I change the "Gender" field to "Male"
    Then I should see the Save bar
    When I click "Discard"
    Then the "Gender" field should be reverted
