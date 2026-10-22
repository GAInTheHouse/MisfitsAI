# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db/seeds/demo_user").to_s

# Fixed on behalf of Phase 1: the demo account never gets a known password in production, and db:seed never
# prints the password.
RSpec.describe "Demo user seed" do
  def seed_output
    original = $stdout
    $stdout = StringIO.new
    Rails.application.load_seed
    $stdout.string
  ensure
    $stdout = original
  end

  def demo_user = User.find_by(email: DemoUser::EMAIL)

  around do |example|
    original = ENV.fetch("DEMO_PASSWORD", nil)
    example.run
  ensure
    original.nil? ? ENV.delete("DEMO_PASSWORD") : ENV["DEMO_PASSWORD"] = original
  end

  it "never prints the password" do
    ENV["DEMO_PASSWORD"] = "a-very-secret-demo-pw"
    output = seed_output
    expect(output).to include(DemoUser::EMAIL)
    expect(output).not_to include("a-very-secret-demo-pw")
    expect(demo_user.valid_password?("a-very-secret-demo-pw")).to be(true)
  end

  it "keeps the development default outside production" do
    ENV.delete("DEMO_PASSWORD")
    expect(seed_output).not_to include(DemoUser::DEVELOPMENT_PASSWORD)
    expect(demo_user.valid_password?(DemoUser::DEVELOPMENT_PASSWORD)).to be(true)
  end

  context "in production" do
    before { allow(Rails.env).to receive(:production?).and_return(true) }

    it "creates no demo account (and no wardrobe) when DEMO_PASSWORD is not set, so db:prepare stays safe" do
      ENV.delete("DEMO_PASSWORD")
      expect(seed_output).to include("Demo user skipped")
      expect(demo_user).to be_nil
      expect(Garment.count).to eq(0)
    end

    it "treats a blank DEMO_PASSWORD as not set" do
      ENV["DEMO_PASSWORD"] = "  "
      seed_output
      expect(demo_user).to be_nil
    end

    [ "changeme", "CHANGEME", "password", "short-pw" ].each do |weak|
      it "refuses #{weak.inspect} and creates nothing" do
        ENV["DEMO_PASSWORD"] = weak
        expect { seed_output }.to raise_error(DemoUser::InsecurePasswordError)
        expect(demo_user).to be_nil
      end
    end

    it "does not change an existing demo account's password to a weak one" do
      user = create(:user, email: DemoUser::EMAIL, password: "a-strong-demo-password",
                         password_confirmation: "a-strong-demo-password")
      ENV["DEMO_PASSWORD"] = "changeme"
      expect { seed_output }.to raise_error(DemoUser::InsecurePasswordError)
      expect(user.reload.valid_password?("changeme")).to be(false)
    end

    it "creates the account with an explicitly configured strong password" do
      ENV["DEMO_PASSWORD"] = "a-strong-demo-password"
      seed_output
      expect(demo_user.valid_password?("a-strong-demo-password")).to be(true)
    end
  end
end
