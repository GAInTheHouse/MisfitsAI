# frozen_string_literal: true

# No real DNS in Cucumber either: Media::SafeFetcher resolves through FakeDns (spec/support/fake_dns.rb).
require Rails.root.join("spec/support/fake_dns").to_s

Before { FakeDns.install! }
