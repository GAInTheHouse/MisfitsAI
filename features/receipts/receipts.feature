Feature: Add garments from a receipt
  As a user who shops online
  I want to paste or upload a receipt
  So that the clothes I bought are added to my wardrobe

  # Design doc 6.12 (Receipts::TextParser, PDF, VisionParser).
  # The AI is always the fake adapter.

  Background:
    Given I am signed in as an onboarded user

  Scenario: Pasted receipt text becomes editable rows
    When I paste this receipt text:
      """
      UNIQLO
      Order #12345
      Oxford Shirt White M $39.90
      Slim Fit Chinos Khaki 32 $49.90
      Subtotal $89.80
      Tax $7.18
      Total $96.98
      """
    Then I should see 2 receipt rows
    And I should see a receipt row for "Oxford Shirt White" with price "39.90"
    And I should see a receipt row for "Slim Fit Chinos Khaki" with price "49.90"
    And I should not see a receipt row for "Subtotal"

  Scenario: Low-confidence items are flagged for review
    When I paste this receipt text:
      """
      Graphic tee
      """
    Then I should see 1 receipt row
    And the receipt row "Graphic Tee" should be flagged "Please double-check"

  Scenario: Add selected creates garments with a price note
    When I paste this receipt text:
      """
      UNIQLO
      Oxford Shirt White M $39.90
      Slim Fit Chinos Khaki 32 $49.90
      """
    And I exclude the receipt row "Slim Fit Chinos Khaki"
    And I click "Add selected"
    Then my wardrobe should contain "Oxford Shirt White"
    And my wardrobe should not contain "Slim Fit Chinos Khaki"
    And the garment "Oxford Shirt White" should have the fit note "Receipt price: $39.90"

  Scenario: Receipt garments get product images by default
    When I paste this receipt text:
      """
      Oxford Shirt White M $39.90
      """
    And I click "Add selected"
    And background jobs finish
    Then the garment "Oxford Shirt White" should have a generated image

  Scenario: Product images can be skipped
    When I paste this receipt text:
      """
      Oxford Shirt White M $39.90
      """
    And I uncheck "Generate product images"
    And I click "Add selected"
    And background jobs finish
    Then the garment "Oxford Shirt White" should use a placeholder image
    And no AI image generation should have been requested

  Scenario: A PDF receipt is parsed
    When I upload the receipt "receipt.pdf"
    Then I should see a receipt row for "Oxford Shirt White" with price "39.90"

  Scenario: An image receipt is read by the vision job
    Given the AI will read these items from my receipt image:
      | name         | brand  | size | color | category | price | confidence |
      | Denim Jacket | Levi's | L    | blue  | outerwear | 89.50 | 0.9        |
    When I upload the receipt "receipt.jpg"
    And background jobs finish
    Then I should see a receipt row for "Denim Jacket" with price "89.50"

  Scenario: A receipt file over 10 MB is rejected
    When I upload an 11 MB receipt file
    Then I should see "File too large"

  Scenario: The Receipt tab is hidden when the feature is switched off
    Given the "receipts" feature is disabled
    When I am on the wardrobe page
    Then I should not see the tab "Receipt"

  @javascript
  Scenario: Add receipt items from the wardrobe's Receipt tab
    Given I am on the wardrobe page
    When I paste this receipt text:
      """
      ZARA
      Wide Leg Trousers Black 38 $59.90
      """
    Then I should see 1 receipt row
    When I click "Add selected"
    Then I should see "1 item added"
    And I should see the garment "Wide Leg Trousers Black"
    And the garment "Wide Leg Trousers Black" should have the fit note "Receipt price: $59.90"
