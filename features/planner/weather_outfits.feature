Feature: Weather-aware outfits
  As someone who dresses for the forecast
  I want outerwear when it is cold and lighter looks when it is hot
  So that I am comfortable all week

  Background:
    Given I am signed in as an onboarded user
    And my wardrobe contains:
      | name               | category  | formality | color | sub_category |
      | White Oxford Shirt | top       | business  | white | shirt        |
      | Black Dress Pants  | bottom    | business  | black | dress_pants  |
      | Navy Peacoat       | outerwear | business  | navy  | coat         |
      | White Sneakers     | shoes     | casual    | white | sneakers     |
    And my week is:
      | day    | event_type   |
      | Monday | work_meeting |

  @cold_weather
  Scenario: A cold Monday adds outerwear to the outfit
    When I generate outfits for my week
    Then Monday's outfit should include "Navy Peacoat"

  @hot_weather
  Scenario: A hot Monday leaves outerwear out of the outfit
    When I generate outfits for my week
    Then Monday's outfit should not include "Navy Peacoat"