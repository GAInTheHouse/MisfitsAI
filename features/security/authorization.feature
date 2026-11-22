Feature: Authorization
  As a signed-in user
  I should only access my own records

  Scenario: Another user's garment returns 404 for edit, hide, and delete
    Given another user owns a garment
    When I try to edit the other user's garment
    Then I should get a not found response
    When I try to hide the other user's garment
    Then I should get a not found response
    When I try to delete the other user's garment
    Then I should get a not found response

  Scenario: Another user's outfit and week events return 404
    Given another user has a planned week with an outfit
    When I try to view the other user's outfit
    Then I should get a not found response
    When I try to change the other user's week event
    Then I should get a not found response
    And the other user's week event should be unchanged
