# frozen_string_literal: true

require "rails_helper"
require "open3"

# config/initializers/vips.rb: one libvips thread and no operation cache when ruby-vips loaded, and no crash when
# libvips is missing (ruby-vips then leaves an empty Vips module behind; Active Storage rescues the LoadError).
RSpec.describe "config/initializers/vips.rb" do
  let(:initializer) { Rails.root.join("config/initializers/vips.rb").to_s }

  # Loads the initializer in a clean Ruby process after the given setup, so the real Vips is not involved.
  def load_with(setup)
    Open3.capture3(RbConfig.ruby, "-e", "#{setup}; load ARGV[0]; puts 'loaded'", initializer)
  end

  it "applies the concurrency limit and disables the cache in the booted app" do
    expect(Vips.vips_concurrency_get).to eq(1)
    expect(Vips.cache_max).to eq(0)
  end

  it "does not crash when libvips is missing and only an empty Vips module exists" do
    out, err, status = load_with("module Vips; end")
    expect(status).to be_success, err
    expect(out).to include("loaded")
  end

  it "does not crash when Vips only partly loaded (one of the two methods missing)" do
    [ "def self.concurrency_set(n) = nil", "def self.cache_set_max(n) = nil" ].each do |only|
      out, err, status = load_with("module Vips; #{only}; end")
      expect(status).to be_success, err
      expect(out).to include("loaded")
    end
  end

  it "sets concurrency 1 and cache 0 when ruby-vips is loaded" do
    setup = "module Vips; CALLS = []; def self.concurrency_set(n) = CALLS << [:concurrency_set, n]; " \
            "def self.cache_set_max(n) = CALLS << [:cache_set_max, n]; end; at_exit { p Vips::CALLS }"
    out, err, status = load_with(setup)
    expect(status).to be_success, err
    expect(out).to include("[[:concurrency_set, 1], [:cache_set_max, 0]]")
  end
end
