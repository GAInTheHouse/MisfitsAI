# frozen_string_literal: true

require "rails_helper"

RSpec.describe Avatars::SelfieUpload do
  describe ".accept" do
    it "rejects a blank file" do
      expect(described_class.accept(nil)).to have_attributes(ok: false, error: "Uploaded file is empty")
    end

    it "accepts a valid JPEG" do
      path = Rails.root.join("spec/fixtures/files/outfit.jpg")
      file = fixture_file_upload(path, "image/jpeg")
      expect(described_class.accept(file)).to have_attributes(ok: true, error: nil)
    end
  end
end