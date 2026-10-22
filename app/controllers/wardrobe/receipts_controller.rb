# frozen_string_literal: true

module Wardrobe
  # Receipt intake (design doc 6.12): pasted text, a PDF or a text file is parsed in the request; a receipt
  # image is read by Receipts::ParseImageJob. Views render inside the "receipt_intake" Turbo Frame of the
  # wardrobe page (and stand alone without JS).
  class ReceiptsController < ApplicationController
    include IntakeUpload

    MAX_BYTES = 10.megabytes
    MAX_TEXT = 20_000 # characters of pasted text; a receipt or order email fits easily
    IMAGE_TYPES = %w[image/jpeg image/png image/webp image/heic].freeze

    TOO_LARGE = "File too large"
    TEXT_TOO_LONG = "That text is too long. Paste just the receipt or order email."
    NOTHING = "Paste receipt text or choose a file"
    EMPTY = "Uploaded file is empty"
    UNSUPPORTED = "Please upload a receipt image, PDF or text file"

    before_action :require_feature!
    before_action :set_batch, only: :show

    def new; end

    def create
      file = params[:receipt_file]
      text = params[:receipt_text].to_s
      return create_from_file(file) if file.respond_to?(:read)
      return render_new_error(NOTHING) if text.strip.blank?
      return render_new_error(TEXT_TOO_LONG) if text.length > MAX_TEXT

      batch = Receipts::Intake.from_text(user: current_user, text: text, strategy: "text_rules")
      redirect_to wardrobe_receipt_path(batch)
    end

    def show; end

    private

    def require_feature!
      head :not_found unless Feature.enabled?(:receipts)
    end

    def set_batch
      @batch = current_user.intake_batches.receipts.find(params[:id])
    end

    # The type comes from the file's bytes, never its name or Content-Type.
    def create_from_file(file)
      return render_new_error(EMPTY) if file.size.zero?
      return render_new_error(TOO_LARGE) if file.size > MAX_BYTES

      head_bytes = file.read(64.kilobytes).to_s
      file.rewind
      type = Marcel::MimeType.for(StringIO.new(head_bytes))

      batch =
        if type == "application/pdf"
          pdf = file.respond_to?(:to_io) ? file.to_io : file # PDF::Reader needs the seekable temp file
          Receipts::Intake.from_text(user: current_user, text: Receipts::PdfText.call(pdf), strategy: "pdf_text_rules")
        elsif IMAGE_TYPES.include?(type) && heic_allowed?(type)
          image_batch(file)
        elsif plain_text?(head_bytes)
          text = file.read(MAX_TEXT).to_s.force_encoding(Encoding::UTF_8).scrub # a cut may split a character
          Receipts::Intake.from_text(user: current_user, text: text, strategy: "plain_text_rules")
        else
          return render_new_error(UNSUPPORTED)
        end
      redirect_to wardrobe_receipt_path(batch)
    rescue Receipts::UnreadableError => e
      render_new_error(e.user_message)
    end

    # Stored first, then queued (IntakeUpload), like photo uploads.
    def image_batch(file)
      create_upload_batch(file: file, job: Receipts::ParseImageJob, kind: "receipt", parser_strategy: "image_vision")
    end

    def heic_allowed?(type)
      type != "image/heic" || ActiveModel::Type::Boolean.new.cast(ENV.fetch("HEIC_SUPPORTED", "true"))
    end

    # Text files: valid UTF-8 without control characters other than tabs and line breaks.
    def plain_text?(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? && !text.match?(/[\x00-\x08\x0B\x0C\x0E-\x1F]/)
    end

    def render_new_error(message)
      @error = message
      render :new, status: :unprocessable_entity
    end
  end
end
