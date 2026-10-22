# frozen_string_literal: true

# Steps such as "the {string} feature is disabled" or "AI image generation is disabled" change ENV.
# Restore it after every scenario so those changes never leak into the next one.
Around do |_scenario, block|
  original_env = ENV.to_h
  block.call
ensure
  ENV.replace(original_env)
end
