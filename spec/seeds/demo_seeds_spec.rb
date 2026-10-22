# frozen_string_literal: true

require "rails_helper"
require "vips"
require Rails.root.join("db/seeds/demo_wardrobe").to_s

# design doc 9.4: db:seed creates the demo user with a 15-item wardrobe with images, and stays repeatable.
RSpec.describe "Demo seeds" do
  include ActiveJob::TestHelper

  def seed = silence_stream($stdout) { Rails.application.load_seed }
  def demo_user = User.find_by!(email: "demo@misfit.ai")

  def silence_stream(stream)
    original = stream.dup
    stream.reopen(File::NULL)
    yield
  ensure
    stream.reopen(original)
  end

  it "gives the demo user 15 garments, each with a 512x512 JPEG image and ready status" do
    seed
    garments = demo_user.garments.includes(image_attachment: :blob)
    expect(garments.size).to eq(15)
    expect(garments.map(&:image_status)).to all(eq("ready"))
    garments.each do |garment|
      expect(garment.image).to be_attached
      image = Vips::Image.new_from_buffer(garment.image.download, "")
      expect([ image.width, image.height ]).to eq([ 512, 512 ])
    end
  end

  it "covers every category and supports outfit planning" do
    seed
    expect(demo_user.garments.distinct.pluck(:category)).to match_array(Garment::CATEGORIES)
    expect(demo_user.garments.visible.outfit_ready?).to be(true)
    expect(demo_user.garments.pluck(:formality).uniq).to include("business", "smart_casual", "casual")
  end

  it "is repeatable: running it again adds no garments, images or files" do
    seed
    counts = -> { [ demo_user.garments.count, ActiveStorage::Blob.count, ActiveStorage::Attachment.count ] }
    first = counts.call
    seed
    expect(counts.call).to eq(first)
  end

  it "keeps what the planner and the user changed" do
    seed
    shirt = demo_user.garments.find_by!(name: "White Oxford Shirt")
    shirt.update!(times_recommended: 7, hidden_from_recommendations: true)
    extra = create(:garment, user: demo_user, name: "My Own Scarf", category: "accessory")
    seed
    expect(shirt.reload).to have_attributes(times_recommended: 7, hidden_from_recommendations: true)
    expect(Garment.exists?(extra.id)).to be(true)
  end

  it "never changes a garment the user added with the same name as a demo garment" do
    user = create(:user, email: "demo@misfit.ai")
    own = create(:garment, user:, name: "White Oxford Shirt", category: "dress", brand: "Mine", source: "manual",
                           times_recommended: 3, hidden_from_recommendations: true)
    seed
    seed
    expect(own.reload).to have_attributes(
      name: "White Oxford Shirt", category: "dress", brand: "Mine", source: "manual", source_url: nil,
      times_recommended: 3, hidden_from_recommendations: true, image_status: "placeholder"
    )
    expect(own.image).not_to be_attached
    expect(demo_user.garments.where(name: "White Oxford Shirt").count).to eq(2) # the user's and the demo one
    expect(demo_user.garments.where(source: "starter").count).to eq(15)
  end

  it "only updates garments it seeded (marked by a demo-seed: source_url)" do
    seed
    expect(demo_user.garments.pluck(:source_url)).to all(start_with(DemoWardrobe::MARKER_PREFIX))
    starter = create(:garment, user: demo_user, name: "Navy Crewneck Sweater", category: "top", source: "starter")
    seed
    expect(starter.reload).to have_attributes(source_url: nil, image_status: "placeholder")
  end

  it "restores a demo garment's image if it went missing" do
    seed
    shirt = demo_user.garments.find_by!(name: "White Oxford Shirt")
    shirt.image.purge
    shirt.update!(image_status: "placeholder")
    seed
    expect(shirt.reload.image).to be_attached
    expect(shirt.image_status).to eq("ready")
  end

  it "makes no AI calls and queues no image jobs" do
    expect { seed }.not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
    expect(Ai::Client::Fake.calls).to be_empty
  end

  it "has an image file for every item" do
    DEMO_WARDROBE_ITEMS.each { expect(File).to exist(Rails.root.join("db/seeds/images", _1[:image])) }
  end
end
