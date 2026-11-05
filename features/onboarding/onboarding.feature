Feature: Onboarding
  As a new user
  I want a guided setup
  So that I get useful outfits on day one

  @javascript
  Scenario: Complete onboarding with the starter catalog
    Given I have just signed up with email "new@example.com"
    Then I should be on the onboarding page
    When I choose gender "Female" and continue
    And I choose aesthetics "Casual" and "Minimalist" and continue
    And I select "White T-shirt", "Blue Jeans" and "White Sneakers" from the catalog
    And I click "Build My Wardrobe"
    Then I should see "Your first week of outfits"
    When background jobs finish
    When I click "Enter My Wardrobe"
    Then I should be on the wardrobe page

  Scenario: Invalid birthday blocks Continue
    Given I have just signed up with email "bday@example.com"
    When I fill in "Birthday" with "not-a-date"
    And I click "Continue"
    Then I should see "Use YYYY-MM-DD format"

  Scenario: Build My Wardrobe is disabled with no catalog items
    Given I have just signed up with email "empty@example.com"
    When I continue through step 0
    And I continue through step 1
    Then "Build My Wardrobe" should be disabled

  Scenario: A custom item can be added in step 3
    Given I have just signed up with email "custom@example.com"
    When I continue through step 0
    And I continue through step 1
    And I select "White T-shirt" and "Blue Jeans" from the catalog
    And I click "Add custom item"
    And I fill in the custom item name "Linen Shirt" with category "Top"
    Then I should see "Linen Shirt"

  Scenario: Refreshing resumes at the same step
    Given I have just signed up with email "refresh@example.com"
    When I continue through step 0
    And I visit "/onboarding"
    Then I should see "Your style"

  Scenario: Enter My Wardrobe completes onboarding
    Given I am on step 4 of onboarding
    When I click "Enter My Wardrobe"
    Then I should be on the wardrobe page
    And I should be onboarded
