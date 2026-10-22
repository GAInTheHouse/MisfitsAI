# frozen_string_literal: true

# config/cable.yml uses the async adapter in test so Cucumber's browser receives Turbo Stream broadcasts.
# RSpec asserts on broadcasts instead (have_broadcasted_to), which needs the test adapter, so swap it in
# for every example the same way ActionCable::TestHelper does.
RSpec.configure do |config|
  config.before do
    @original_cable_pubsub = ActionCable.server.pubsub
    ActionCable.server.instance_variable_set(:@pubsub, ActionCable::SubscriptionAdapter::Test.new(ActionCable.server))
  end

  config.after do
    ActionCable.server.instance_variable_set(:@pubsub, @original_cable_pubsub)
  end
end
