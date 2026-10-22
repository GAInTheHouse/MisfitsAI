Feature: Add a garment from an image search
  As a user who knows what I own
  I want to search for a product photo and pick it
  So that my wardrobe shows a clean image of the item

  # Design doc 6.5 (ImageSearch, FilterAndRank, ImportRemoteImageJob).
  # SerpAPI is always mocked; no real network calls are made.
  # Image hosts resolve through FakeDns (spec/support/fake_dns.rb); nothing reaches the network.

  Background:
    Given I am signed in as an onboarded user
    And I am on the wardrobe page

  Scenario: Search shows product results
    Given the image search returns:
      | title                          | original                                  | thumbnail                                 | link                               |
      | Uniqlo Oxford Shirt White      | https://images.example.com/oxford.jpg     | https://images.example.com/oxford_t.jpg   | https://shop.example.com/oxford    |
      | Uniqlo Linen Shirt White       | https://images.example.com/linen.jpg      | https://images.example.com/linen_t.jpg    | https://shop.example.com/linen     |
    When I search for garments with brand "Uniqlo" and keywords "white shirt"
    Then I should see 2 search results
    And I should see the search result "Uniqlo Oxford Shirt White"

  Scenario: Picking a result adds the garment and imports its image
    Given the image search returns:
      | title                     | original                              | thumbnail                               | link                            |
      | Uniqlo Oxford Shirt White | https://images.example.com/oxford.jpg | https://images.example.com/oxford_t.jpg | https://shop.example.com/oxford |
    And the image at "https://images.example.com/oxford.jpg" can be downloaded
    When I search for garments with brand "Uniqlo" and keywords "white shirt"
    And I pick the search result "Uniqlo Oxford Shirt White"
    Then my wardrobe should contain "Uniqlo Oxford Shirt White"
    When background jobs finish
    Then the garment "Uniqlo Oxford Shirt White" should have an imported image

  Scenario: Off-topic results are filtered out
    Given the image search returns:
      | title              | original                             | thumbnail                              | link                            |
      | Black Cotton Top   | https://images.example.com/top.jpg   | https://images.example.com/top_t.jpg   | https://shop.example.com/top    |
      | Black Laptop Stand | https://images.example.com/stand.jpg | https://images.example.com/stand_t.jpg | https://shop.example.com/stand  |
    When I search for garments with keywords "black top"
    Then I should see the search result "Black Cotton Top"
    And I should not see the search result "Black Laptop Stand"

  Scenario: A brand or keywords are required
    When I search for garments with no brand or keywords
    Then I should see "Enter a brand or keywords"

  Scenario: The search provider fails
    Given the image search provider returns an error
    When I search for garments with keywords "white shirt"
    Then I should see "Garment search provider failed. Try again later."

  Scenario: The search provider times out
    Given the image search times out
    When I search for garments with keywords "white shirt"
    Then I should see "Garment search request failed. Please retry."

  Scenario: Search is not configured
    Given image search is not configured
    When I search for garments with keywords "white shirt"
    Then I should see "Garment search is not configured"

  Scenario: An image that cannot be downloaded falls back to the placeholder
    Given the image search returns:
      | title                     | original                              | thumbnail                               | link                            |
      | Uniqlo Oxford Shirt White | https://images.example.com/oxford.jpg | https://images.example.com/oxford_t.jpg | https://shop.example.com/oxford |
    And the image at "https://images.example.com/oxford.jpg" cannot be downloaded
    When I search for garments with brand "Uniqlo" and keywords "white shirt"
    And I pick the search result "Uniqlo Oxford Shirt White"
    And background jobs finish
    Then the garment "Uniqlo Oxford Shirt White" should use a placeholder image
    And I should see "Couldn't download that image; using a placeholder."

  Scenario: An image hosted on a private address is never fetched
    Given the image search returns:
      | title                     | original                         | thumbnail                          | link                            |
      | Uniqlo Oxford Shirt White | http://169.254.169.254/latest.jpg | http://169.254.169.254/thumb.jpg | https://shop.example.com/oxford |
    When I search for garments with brand "Uniqlo" and keywords "white shirt"
    And I pick the search result "Uniqlo Oxford Shirt White"
    And background jobs finish
    Then the garment "Uniqlo Oxford Shirt White" should use a placeholder image
    And no request should have been made to "169.254.169.254"

  @javascript
  Scenario: Search and add a result without leaving the wardrobe page
    Given the image search returns:
      | title                     | original                              | thumbnail                               | link                            |
      | Uniqlo Oxford Shirt White | https://images.example.com/oxford.jpg | https://images.example.com/oxford_t.jpg | https://shop.example.com/oxford |
    And the image at "https://images.example.com/oxford.jpg" can be downloaded
    When I open the "Search" tab
    And I search for garments with brand "Uniqlo" and keywords "white shirt"
    Then I should see 1 search result
    When I pick the search result "Uniqlo Oxford Shirt White"
    Then I should see the garment "Uniqlo Oxford Shirt White"
    And I should see "Added Uniqlo Oxford Shirt White to your wardrobe."
    When background jobs finish
    Then the card for "Uniqlo Oxford Shirt White" should update to its imported image
