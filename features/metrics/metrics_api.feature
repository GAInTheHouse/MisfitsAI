Feature: Metrics API
  As the product team
  I want an internal metrics endpoint
  So that we can track growth

  Scenario: Key is required
    When I call GET "/api/metrics" without a key
    Then the response status should be 401

  Scenario: Wrong key is rejected
    When I call GET "/api/metrics" with the wrong key
    Then the response status should be 401

  Scenario: Shape of /api/metrics
    Given the analytics key is configured
    When I call GET "/api/metrics" with the correct key
    Then the response should include "signups"
    And the response should include "active_users"
    And the response should include "page_views"
    And the response should include "waitlist"

  Scenario: Dummy mode returns stub values
    Given the analytics key is configured
    And dummy metrics mode is enabled
    When I call GET "/api/metrics" with the correct key
    Then "signups" should be 2
    And "active_users" should be 3
    And "dummy_data" should be true

  Scenario: GA4 failure gives zeros with ga4_configured false
    Given the analytics key is configured
    And the GA4 API is unavailable
    When I call GET "/admin/metrics" with the correct key
    Then "active_users" should be 0
    And "ga4_configured" should be false

  Scenario: period_days is clamped to 1..366
    Given the analytics key is configured
    When I call GET "/api/metrics?period_days=999" with the correct key
    Then the response should succeed
