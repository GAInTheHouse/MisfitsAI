Feature: Avatar generation
  As a user
  I want to generate an illustrated avatar from my selfie
  So that I can visualize outfits on myself

  Background:
    Given I am signed in as an onboarded user

  Scenario: Upload a selfie and the avatar appears
    Given I visit "/profile"
    When I upload "selfie.jpg" as my avatar selfie
    And background jobs finish
    Then I should see my avatar image
    And the selfie should not be stored

  Scenario: A non-image file is rejected
    Given I visit "/profile"
    When I upload "document.pdf" as my avatar selfie
    Then I should see "Please upload a JPEG, PNG, WebP or HEIC image"

  Scenario: A file over 15 MB is rejected
    Given I visit "/profile"
    When I upload an oversized file as my avatar selfie
    Then I should see "Image too large"

  Scenario: Generation failure shows an error
    Given the AI service fails for "avatar_portrait"
    And I visit "/profile"
    When I upload "selfie.jpg" as my avatar selfie
    And background jobs finish
    Then I should see "Avatar generation failed"
