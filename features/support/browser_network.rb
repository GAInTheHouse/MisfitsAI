# frozen_string_literal: true

# Browser scenarios may only load pages from the test server. Anything else (remote search thumbnails,
# web fonts) is blocked, so @javascript scenarios never depend on the internet.
Before("@javascript") do
  page.driver.browser.url_allowlist = [ %r{\Ahttp://127\.0\.0\.1:\d+/}, %r{\Ahttp://localhost:\d+/} ]
end
