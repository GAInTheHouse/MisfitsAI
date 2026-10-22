# frozen_string_literal: true

# A test-only job that enqueues the next link of a chain, so the harness can prove that
# "When background jobs finish" also runs jobs enqueued by other jobs.
class HarnessChainJob < ApplicationJob
  cattr_accessor :performed, default: []

  def perform(link, length)
    performed << link
    HarnessChainJob.perform_later(link + 1, length) if link < length
  end
end

Before { HarnessChainJob.performed = [] }
