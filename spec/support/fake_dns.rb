# frozen_string_literal: true

require "ipaddr"

# Deterministic DNS for Media::SafeFetcher in tests: no real lookups, and tests can say which hosts resolve
# to public or private addresses. Used by RSpec (below) and Cucumber (features/support/fake_dns.rb).
module FakeDns
  PUBLIC_IP = "93.184.215.14"

  DEFAULT_HOSTS = {
    "example.com" => [ PUBLIC_IP ],
    "images.example.com" => [ PUBLIC_IP ],
    "shop.example.com" => [ PUBLIC_IP ],
    "cdn.example.com" => [ PUBLIC_IP ]
  }.freeze

  mattr_accessor :hosts, default: DEFAULT_HOSTS.dup

  RESOLVER = lambda do |hostname|
    literal = begin
      IPAddr.new(hostname.to_s.delete_prefix("[").delete_suffix("]"))
    rescue IPAddr::InvalidAddressError
      nil
    end
    next [ literal ] if literal

    Array(FakeDns.hosts[hostname.to_s.downcase]).map { IPAddr.new(_1) }
  end

  def self.install!
    self.hosts = DEFAULT_HOSTS.dup
    Media::SafeFetcher.resolver = RESOLVER
  end

  def self.map(hostname, *ips)
    hosts[hostname.downcase] = ips
  end
end

if defined?(RSpec::Core)
  RSpec.configure do |config|
    config.before { FakeDns.install! }
  end
end
