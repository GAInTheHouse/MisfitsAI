# frozen_string_literal: true

# Shared by the jobs that process an intake batch (photo and receipt image): failing the batch, deleting the
# uploaded file once the batch is finished, and broadcasting the batch card. The including job sets @batch
# and defines #batch_partial.
module IntakeBatchJobSupport
  extend ActiveSupport::Concern

  included do
    # Handlers declared later win, so this catch-all must come before the job's specific handlers.
    rescue_from(StandardError) do |error|
      # The batch was discarded or purged while the job ran: nothing left to report, nothing to recreate.
      next unless IntakeBatch.exists?(arguments.first)

      fail_batch(self.class::PROCESSING_FAILED)
      raise error
    end
  end

  private

  # Always works on a freshly loaded batch. The failure may come from a rolled-back transaction that created
  # drafts through @batch.garment_drafts; those objects are unsaved again but still in @batch's association, and
  # saving @batch would insert them again.
  def fail_batch(message)
    @batch = IntakeBatch.find_by(id: arguments.first)
    return unless @batch

    @batch.mark_failed!(message)
    purge_source
    broadcast_batch
  end

  def purge_source
    @batch.source_file.purge_later if @batch.source_file.attached?
  end

  def broadcast_batch
    Turbo::StreamsChannel.broadcast_replace_to(
      [ @batch.user, :wardrobe ], target: @batch, partial: batch_partial, locals: { batch: @batch.reload }
    )
  end
end
