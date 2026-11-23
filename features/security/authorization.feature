Feature: Authorization
  As a signed-in user
  I want my closet and plans to stay private
  So that other accounts cannot change my clothes or outfits

  Scenario: I cannot edit, hide, or delete someone else's clothes
    Given another user owns a garment
    When I try to edit the other user's garment
    Then I should get a not found response
    When I try to hide the other user's garment
    Then I should get a not found response
    When I try to delete the other user's garment
    Then I should get a not found response

  Scenario: I cannot open or change someone else's outfit or week plan
    Given another user has a planned week with an outfit
    When I try to view the other user's outfit
    Then I should get a not found response
    When I try to change the other user's week event
    Then I should get a not found response
    And the other user's week event should be unchanged
