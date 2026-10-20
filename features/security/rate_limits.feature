Feature: Rate limits
  As the platform
  I want to throttle abusive login attempts

  Scenario: The sixth login attempt in 20 s is throttled
    When I attempt to log in 6 times quickly
    Then I should be rate limited
