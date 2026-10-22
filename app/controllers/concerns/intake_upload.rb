# frozen_string_literal: true

# Creates an intake batch for an uploaded file and queues its processing job, in an order that keeps the job
# from ever running before its data exists (photo intake 6.6, receipt images 6.12):
#
# 1. the batch row is saved;
# 2. the file is attached outside any surrounding transaction, so when attach returns the attachment is
#    committed and the file is in storage (Active Storage uploads in an after-commit callback);
# 3. only then is the job queued.
#
# If step 2 or 3 fails, the stored file (if any) is deleted and the batch removed, so no orphaned file or
# half-made batch is left behind. Wrapping all three in one transaction would let a worker pick up the job
# at commit while the request is still uploading the file.
module IntakeUpload
  extend ActiveSupport::Concern

  private

  def create_upload_batch(file:, job:, **attributes)
    batch = current_user.intake_batches.create!(status: "processing", **attributes)
    begin
      batch.source_file.attach(file)
      job.perform_later(batch.id)
    rescue StandardError
      discard_upload(batch)
      raise
    end
    batch
  end

  def discard_upload(batch)
    blob = batch.source_file.blob if batch.source_file.attached?
    batch.destroy
    blob&.purge # deletes the stored file now (not via a job, which may be what failed)
  rescue StandardError => e
    Rails.logger.error("[IntakeUpload] cleanup of batch #{batch.id} failed: #{e.class}")
  end
end
