# frozen_string_literal: true

# Captures the <turbo-stream> elements broadcast to a stream while the block runs.
# turbo-rails' own capture_turbo_stream_broadcasts depends on Minitest assertion internals, so this reads
# the Action Cable test adapter (spec/support/action_cable.rb) directly, using Turbo's own stream names.
module TurboStreamHelpers
  include Turbo::Streams::StreamName

  def turbo_stream_broadcasts_to(streamables)
    name = stream_name_from(streamables)
    already_sent = ActionCable.server.pubsub.broadcasts(name).size
    yield
    ActionCable.server.pubsub.broadcasts(name).drop(already_sent).flat_map do |payload|
      Nokogiri::HTML5.fragment(ActiveSupport::JSON.decode(payload)).element_children
    end
  end
end

RSpec.configure do |config|
  config.include TurboStreamHelpers
end
