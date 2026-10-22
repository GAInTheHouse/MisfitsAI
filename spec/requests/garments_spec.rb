# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Garments", type: :request do
  let(:user) { create(:user, :onboarded) }
  let(:turbo_stream) { { "Accept" => "text/vnd.turbo-stream.html" } }

  before { sign_in user }

  describe "GET /wardrobe" do
    it "shows the empty state and the planning hint for an empty closet" do
      get wardrobe_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Your closet is empty. Snap a photo, search for an item, or describe it to get started.")
      expect(response.body).to include("Add at least one top and one bottom to unlock outfit planning.")
      expect(response.body).not_to include("Next: plan your week")
      expect(response.body).to include("0 items")
    end

    it "lists only the signed-in user's garments" do
      create(:garment, user: user, name: "Mine")
      create(:garment, user: create(:user), name: "Someone Else's")
      get wardrobe_path
      expect(response.body).to include('data-name="Mine"')
      expect(response.body).not_to include("Someone Else")
      expect(response.body).to include("1 item")
    end

    it "shows the next-step link with a top and a bottom" do
      create(:garment, :top, user: user)
      create(:garment, :bottom, user: user)
      get wardrobe_path
      expect(response.body).to include("Next: plan your week")
      expect(response.body).not_to include("unlock outfit planning")
    end

    it "keeps the planning hint when the only bottom is hidden from outfits (design doc 6.7)" do
      create(:garment, :top, user: user)
      create(:garment, :bottom, :hidden, user: user)
      get wardrobe_path
      expect(response.body).to include("Add at least one top and one bottom to unlock outfit planning.")
      expect(response.body).not_to include("Next: plan your week")
    end

    it "does not count a hidden dress" do
      create(:garment, :dress, :hidden, user: user)
      get wardrobe_path
      expect(response.body).not_to include("Next: plan your week")
    end

    it "filters by category and ignores unknown categories" do
      create(:garment, :top, user: user, name: "Shirt")
      create(:garment, :bottom, user: user, name: "Chinos")

      get wardrobe_path(category: "bottom")
      expect(response.body).to include('data-name="Chinos"')
      expect(response.body).not_to include('data-name="Shirt"')

      get wardrobe_path(category: "spaceship")
      expect(response.body).to include('data-name="Chinos"', 'data-name="Shirt"')
    end

    it "shows the category placeholder for a garment without an image" do
      create(:garment, :shoes, user: user)
      get wardrobe_path
      expect(response.body).to match(%r{src="/assets/placeholders/shoes-\h+\.jpg"})
    end

    it "shows the card variant for a garment with an image" do
      create(:garment, :with_image, user: user)
      get wardrobe_path
      expect(response.body).to match(%r{src="/rails/active_storage/representations/redirect/})
    end

    it "subscribes to the user's wardrobe stream" do
      get wardrobe_path
      expect(response.body).to include("turbo-cable-stream-source")
    end

    it "hides the Photo AI and Receipt tabs when their features are off" do
      allow(Feature).to receive(:enabled?).and_call_original
      allow(Feature).to receive(:enabled?).with(:photo_intake).and_return(false)
      allow(Feature).to receive(:enabled?).with(:receipts).and_return(false)
      get wardrobe_path
      expect(response.body).not_to include(">Photo AI</button>", ">Receipt</button>")
      expect(response.body).to include(">Describe item</button>")
    end

    it "does not run more queries as the number of garments grows" do
      create_list(:garment, 2, :with_image, user: user)
      get wardrobe_path # warm up
      few = count_queries { get wardrobe_path }

      create_list(:garment, 4, :with_image, user: user)
      many = count_queries { get wardrobe_path }

      expect(many).to eq(few)
    end
  end

  describe "POST /garments" do
    let(:params) { { garment: { name: "White Oxford Shirt", category: "top", color_primary: "White" } } }

    it "creates a manual garment with a placeholder image and the defaults (design doc 6.4)" do
      expect { post garments_path, params: params }.to change(user.garments, :count).by(1)
      expect(response).to redirect_to(wardrobe_path)
      expect(user.garments.last).to have_attributes(
        name: "White Oxford Shirt", category: "top", color_primary: "white", source: "manual",
        image_status: "placeholder", formality: "casual", seasonality: "all_season"
      )
    end

    it "queues a product image when 'Generate a product image' is checked, keeping the placeholder status" do
      expect { post garments_path, params: params.merge(generate_image: "1") }
        .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).with(kind_of(String))
      expect(user.garments.last.image_status).to eq("placeholder")
    end

    it "queues nothing when the box is unchecked" do
      expect { post garments_path, params: params }.not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
    end

    it "queues nothing when the garment is invalid" do
      expect { post garments_path, params: { garment: { name: "" }, generate_image: "1" } }
        .not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
    end

    it "keeps chosen formality and season" do
      post garments_path, params: { garment: { name: "Wool Coat", category: "outerwear", formality: "business",
                                                seasonality: "cold" } }
      expect(user.garments.last).to have_attributes(formality: "business", seasonality: "cold")
    end

    it "ignores attributes the form does not offer" do
      other = create(:user)
      post garments_path, params: { garment: params[:garment].merge(user_id: other.id, source: "receipt",
                                                                     image_status: "ready", times_recommended: 9) }
      expect(user.garments.last).to have_attributes(source: "manual", image_status: "placeholder", times_recommended: 0)
      expect(other.garments).to be_empty
    end

    it "responds with Turbo Streams that add the card and refresh the page parts" do
      post garments_path, params: params, headers: turbo_stream
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('action="prepend" target="garments"', 'action="replace" target="wardrobe_status"',
                                       'action="replace" target="manual_garment_form"', 'action="update" target="flash"',
                                       "Added White Oxford Shirt to your wardrobe.")
    end

    it "re-renders the form with errors for invalid input" do
      expect { post garments_path, params: { garment: { name: "", category: "" } } }.not_to change(Garment, :count)
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Name can&#39;t be blank", "Category can&#39;t be blank")
      expect(response.body).not_to include("Category is not included in the list")
    end

    it "replaces only the form with errors for a Turbo Stream request" do
      post garments_path, params: { garment: { name: "a" * 81, category: "top" } }, headers: turbo_stream
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('action="replace" target="manual_garment_form"',
                                       "Name is too long (maximum is 80 characters)")
    end
  end

  describe "PATCH /garments/:id/hide" do
    let!(:garment) { create(:garment, user: user, name: "Grey Hoodie") }

    it "hides and shows a garment" do
      patch hide_garment_path(garment), params: { hidden: "true" }
      expect(garment.reload.hidden_from_recommendations).to be(true)

      patch hide_garment_path(garment), params: { hidden: "false" }
      expect(garment.reload.hidden_from_recommendations).to be(false)
    end

    it "hides when no value is given" do
      patch hide_garment_path(garment)
      expect(garment.reload.hidden_from_recommendations).to be(true)
    end

    it "replaces the card and the header in a Turbo Stream response" do
      patch hide_garment_path(garment), params: { hidden: "true" }, headers: turbo_stream
      expect(response.body).to include(%(action="replace" target="garment_#{garment.id}"), "Hidden from outfits",
                                       "Show in outfits", 'action="replace" target="wardrobe_status"')
    end

    it "returns 404 for another user's garment" do
      foreign = create(:garment)
      patch hide_garment_path(foreign), params: { hidden: "true" }
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.hidden_from_recommendations).to be(false)
    end
  end

  describe "POST /garments/:id/retry_image" do
    it "queues a new image for a failed garment and shows it as pending" do
      garment = create(:garment, user: user, image_status: "failed")
      expect { post retry_image_garment_path(garment), headers: turbo_stream }
        .to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).with(garment.id)
      expect(garment.reload.image_status).to eq("pending")
      expect(response.body).to include(%(target="garment_#{garment.id}"), "Creating image")
    end

    it "queues only one job when Retry image is clicked twice" do
      garment = create(:garment, user: user, image_status: "failed")
      expect do
        2.times { post retry_image_garment_path(garment), headers: turbo_stream }
      end.to have_enqueued_job(Wardrobe::GenerateGarmentImageJob).exactly(:once)
    end

    it "does nothing for a garment whose image is not failed" do
      garment = create(:garment, :with_image, user: user)
      expect { post retry_image_garment_path(garment) }.not_to have_enqueued_job(Wardrobe::GenerateGarmentImageJob)
      expect(garment.reload.image_status).to eq("ready")
    end

    it "shows the Retry image button only on failed cards" do
      create(:garment, user: user, name: "Failed One", image_status: "failed")
      create(:garment, user: user, name: "Fine One")
      get wardrobe_path
      expect(response.body.scan("Retry image").size).to eq(1)
      expect(response.body).to include("Image unavailable")
    end
  end

  describe "DELETE /garments/:id" do
    let!(:garment) { create(:garment, :with_image, :top, user: user, name: "Khaki Chinos") }

    it "deletes the garment and redirects back to the wardrobe" do
      expect { delete garment_path(garment) }.to change(Garment, :count).by(-1)
      expect(response).to redirect_to(wardrobe_path)
      expect(flash[:notice]).to eq("Removed Khaki Chinos.")
    end

    it "purges the image" do
      expect { delete garment_path(garment) }.to have_enqueued_job(ActiveStorage::PurgeJob)
    end

    it "removes the card and shows the empty state when the closet becomes empty" do
      delete garment_path(garment), headers: turbo_stream
      expect(response.body).to include(%(action="remove" target="garment_#{garment.id}"),
                                       'action="update" target="garments"', "Your closet is empty")
    end

    it "keeps outfit recommendations, clearing the deleted slot (design doc 6.4)" do
      plan = WeekPlan.create!(user: user, week_start: Date.new(2026, 10, 19))
      rec = OutfitRecommendation.create!(week_plan: plan, date: plan.week_start, event_type: "casual", top: garment)

      delete garment_path(garment)

      expect(OutfitRecommendation.exists?(rec.id)).to be(true)
      expect(rec.reload.top_id).to be_nil
    end

    it "returns 404 for another user's garment" do
      foreign = create(:garment)
      expect { delete garment_path(foreign) }.not_to change(Garment, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  def count_queries(&block)
    count = 0
    counter = lambda do |*, payload|
      count += 1 unless payload[:name].in?(%w[SCHEMA TRANSACTION]) || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end
