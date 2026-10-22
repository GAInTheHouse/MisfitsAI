Feature: Add garments from an outfit photo
  As a new user
  I want to snap a photo of an outfit and have the pieces recognised
  So that I can digitise my closet quickly

  # Design doc 6.6 (Photo AI intake) and 12.1 (sample scenarios).
  # The AI is always the fake adapter.

  Background:
    Given I am signed in as an onboarded user

  @javascript
  Scenario: Review and commit detected garments
    Given the AI will detect these garments in my photo:
      | item_type        | category | color | formality | seasonality |
      | crewneck sweater | top      | cream | casual    | cold        |
      | straight jeans   | bottom   | blue  | casual    | all_season  |
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    Then I should see 2 draft garments
    When I deselect "Straight Jeans"
    And I click "Add selected"
    Then I should see "1 item added"
    And my wardrobe should contain "Crewneck Sweater"
    And my wardrobe should not contain "Straight Jeans"

  @javascript
  Scenario: Photo intake from the wardrobe's Photo AI tab
    Given the AI will detect these garments in my photo:
      | item_type      | category | color | formality | seasonality |
      | denim jacket   | outerwear | blue | casual    | mild        |
    And I am on the wardrobe page
    When I upload "outfit.jpg" on the Photo AI tab
    Then I should see "Scanning your photo"
    When background jobs finish
    Then I should see 1 draft garment
    When I click "Add selected"
    Then I should see "1 item added"
    And I should see the garment "Denim Jacket"

  Scenario: Committed garments keep the detected details
    Given the AI will detect these garments in my photo:
      | item_type        | category | color | formality | seasonality | pattern | material |
      | crewneck sweater | top      | Cream | casual    | cold        | solid   | wool     |
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    And I click "Add selected"
    Then the garment "Crewneck Sweater" should have these details:
      | category | color_primary | formality | seasonality | pattern | material | source |
      | top      | cream         | casual    | cold        |         | wool     | photo  |

  Scenario: No garments detected
    Given the AI will detect no garments in my photo
    When I upload "blank.jpg" on the Photo AI tab
    And background jobs finish
    Then I should see "No garments detected from image. Please upload a clearer outfit photo."

  Scenario: The AI fails to analyze the photo
    Given the AI service fails for "garment_extraction"
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    Then I should see "We couldn't analyze that photo right now. Please try again."
    And I should see the button "Try again"

  Scenario: At most six drafts are created from one photo
    Given the AI will detect 8 garments in my photo
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    Then I should see 6 draft garments

  Scenario: A draft whose image fails can still be committed
    Given the AI will detect these garments in my photo:
      | item_type      | category | color | formality | seasonality |
      | straight jeans | bottom   | blue  | casual    | all_season  |
    And the AI blocks images for "garment_image"
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    Then I should see 1 draft garment
    When I click "Add selected"
    Then my wardrobe should contain "Straight Jeans"
    And the garment "Straight Jeans" should use a placeholder image

  Scenario: Discard a photo intake
    Given the AI will detect these garments in my photo:
      | item_type        | category | color | formality | seasonality |
      | crewneck sweater | top      | cream | casual    | cold        |
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    And I click "Discard"
    Then I should see 0 draft garments
    And my wardrobe should be empty

  Scenario: The uploaded photo is not kept after analysis
    Given the AI will detect these garments in my photo:
      | item_type        | category | color | formality | seasonality |
      | crewneck sweater | top      | cream | casual    | cold        |
    When I upload "outfit.jpg" on the Photo AI tab
    And background jobs finish
    Then the uploaded photo should not be kept

  Scenario: A photo over 15 MB is rejected
    When I upload a 16 MB photo on the Photo AI tab
    Then I should see "Image too large"
    And no AI analysis should have been requested

  Scenario: A file that is not an image is rejected
    When I upload a non-image file on the Photo AI tab
    Then I should see "Please upload a JPEG, PNG, WebP or HEIC image"
    And no AI analysis should have been requested

  Scenario: The Photo AI tab is hidden when the feature is switched off
    Given the "photo_intake" feature is disabled
    When I am on the wardrobe page
    Then I should not see the tab "Photo AI"
