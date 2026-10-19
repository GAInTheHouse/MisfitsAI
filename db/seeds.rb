# frozen_string_literal: true

demo_email = "demo@misfit.ai"
user = User.find_or_initialize_by(email: demo_email)
user.password = ENV.fetch("DEMO_PASSWORD", "changeme")
user.password_confirmation = user.password
user.name = "Demo User"
user.onboarding_completed_at = Time.current
user.onboarding_step = 4
user.save!

puts "Demo user: #{demo_email} / #{user.password}"
