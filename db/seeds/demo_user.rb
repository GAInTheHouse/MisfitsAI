# frozen_string_literal: true

# Phase 1 seeds (design doc 9.4): the demo account demo@misfit.ai, with its password from DEMO_PASSWORD.
# Fixed on behalf of Phase 1 (docs/handoff/phase-2.md):
# - the password is never printed;
# - production has no default password. Without DEMO_PASSWORD the account is not created (db:prepare seeds a
#   new database, so a deploy must not create an account with a known password), and a weak or known value
#   stops the seed with an error;
# - development and test keep the "changeme" default from .env.example.
module DemoUser
  EMAIL = "demo@misfit.ai"
  DEVELOPMENT_PASSWORD = "changeme"
  KNOWN_PASSWORDS = [ DEVELOPMENT_PASSWORD, "password", "demo", "misfit" ].freeze
  MIN_PRODUCTION_LENGTH = 12

  class InsecurePasswordError < StandardError; end

  module_function

  # The demo user, or nil when production has no DEMO_PASSWORD (nothing is created or changed).
  def seed(env: ENV, production: Rails.env.production?)
    password = password_from(env, production:)
    return if password.nil?

    user = User.find_or_initialize_by(email: EMAIL)
    user.password = password
    user.password_confirmation = password
    user.name = "Demo User"
    user.onboarding_completed_at = Time.current
    user.onboarding_step = 4
    user.save!
    user
  end

  def password_from(env, production:)
    password = env["DEMO_PASSWORD"].presence
    return password || DEVELOPMENT_PASSWORD unless production
    return if password.nil?

    if KNOWN_PASSWORDS.include?(password.downcase) || password.length < MIN_PRODUCTION_LENGTH
      raise InsecurePasswordError,
            "DEMO_PASSWORD is a known or short password; set at least #{MIN_PRODUCTION_LENGTH} characters"
    end
    password
  end
end
