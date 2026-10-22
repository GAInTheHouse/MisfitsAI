Feature: Manage my wardrobe
  As a user with garments in my closet
  I want to browse, filter, hide and remove them
  So that my outfit plans only use what I want to wear

  # Design doc 6.4 (Wardrobe page, Hide, Delete) and 7.2 (empty states).
  # Every scenario is @wip until Phase 2 Step 4 implements it.

  @wip
  Scenario: An empty wardrobe shows the empty state and the planning hint
    Given I am signed in as an onboarded user
    When I am on the wardrobe page
    Then I should see "Your closet is empty. Snap a photo, search for an item, or describe it to get started."
    And I should see "Add at least one top and one bottom to unlock outfit planning."
    And I should not see the link "Next: plan your week"

  @wip
  Scenario: The wardrobe lists my garments with their count
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality    | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business     | white | M    |        | false  | 0                 |
      | Khaki Chinos       | bottom   | smart_casual | khaki | M    |        | false  | 0                 |
    When I am on the wardrobe page
    Then the wardrobe count should be 2
    And I should see the garment "White Oxford Shirt"
    And I should see the garment "Khaki Chinos"

  @wip
  Scenario: Filter the wardrobe by category
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality    | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business     | white | M    |        | false  | 0                 |
      | Khaki Chinos       | bottom   | smart_casual | khaki | M    |        | false  | 0                 |
      | Brown Loafers      | shoes    | smart_casual | brown |      |        | false  | 0                 |
    And I am on the wardrobe page
    When I filter the wardrobe by "Bottom"
    Then I should see the garment "Khaki Chinos"
    And I should not see the garment "White Oxford Shirt"
    And I should not see the garment "Brown Loafers"
    When I filter the wardrobe by "All"
    Then I should see the garment "White Oxford Shirt"
    And I should see the garment "Brown Loafers"

  @wip
  Scenario: Hide a garment from outfits
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business  | white | M    |        | false  | 0                 |
    And I am on the wardrobe page
    When I hide "White Oxford Shirt" from outfits
    Then the garment "White Oxford Shirt" should show the badge "Hidden from outfits"

  @wip
  Scenario: Show a hidden garment in outfits again
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business  | white | M    |        | true   | 0                 |
    And I am on the wardrobe page
    Then the garment "White Oxford Shirt" should show the badge "Hidden from outfits"
    When I show "White Oxford Shirt" in outfits
    Then the garment "White Oxford Shirt" should not show the badge "Hidden from outfits"

  @wip @javascript
  Scenario: Delete a garment after confirming
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name         | category | formality    | color | size | gender | hidden | times_recommended |
      | Khaki Chinos | bottom   | smart_casual | khaki | M    |        | false  | 0                 |
    And I am on the wardrobe page
    When I delete "Khaki Chinos" and confirm "Remove this item from your wardrobe?"
    Then I should not see the garment "Khaki Chinos"
    And my wardrobe should not contain "Khaki Chinos"

  @wip
  Scenario: The next-step link appears once I own a top and a bottom
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality    | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business     | white | M    |        | false  | 0                 |
      | Khaki Chinos       | bottom   | smart_casual | khaki | M    |        | false  | 0                 |
    When I am on the wardrobe page
    Then I should see the link "Next: plan your week"
    And I should not see "Add at least one top and one bottom to unlock outfit planning."

  @wip
  Scenario: The next-step link appears once I own a dress
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name           | category | formality    | color | size | gender | hidden | times_recommended |
      | Red Midi Dress | dress    | smart_casual | red   | M    | women  | false  | 0                 |
    When I am on the wardrobe page
    Then I should see the link "Next: plan your week"

  @wip
  Scenario: A top alone does not unlock planning
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category | formality | color | size | gender | hidden | times_recommended |
      | White Oxford Shirt | top      | business  | white | M    |        | false  | 0                 |
    When I am on the wardrobe page
    Then I should see "Add at least one top and one bottom to unlock outfit planning."
    And I should not see the link "Next: plan your week"
