# frozen_string_literal: true

require "rails_helper"

# ApplicationError handling (design doc 4.3), exercised through an anonymous controller.
RSpec.describe ApplicationController, type: :controller do
  include Devise::Test::ControllerHelpers

  render_views

  controller do
    def index
      raise ApplicationError, "Garment search provider failed. Try again later."
    end
  end

  before { sign_in create(:user, :onboarded) }

  it "updates the #flash container's contents for Turbo Stream requests, keeping the container" do
    get :index, format: :turbo_stream

    stream = Nokogiri::HTML5.fragment(response.body).at("turbo-stream")
    expect(stream["action"]).to eq("update") # regression: was "replace", which removed #flash
    expect(stream["target"]).to eq("flash")
    expect(stream.at("template").text).to include("Garment search provider failed. Try again later.")
    expect(stream.at("template").at("#flash")).to be_nil
  end

  it "keeps showing later errors after a first one (the container survives)" do
    page = Nokogiri::HTML5('<div id="flash"><p>old</p></div>')
    2.times do
      get :index, format: :turbo_stream
      stream = Nokogiri::HTML5.fragment(response.body).at("turbo-stream")
      target = page.at("##{stream['target']}")
      expect(target).not_to be_nil
      # Apply the action the way Turbo does: update swaps the contents, replace swaps the element itself.
      content = stream.at("template").inner_html
      stream["action"] == "replace" ? target.replace(content) : target.inner_html = content
    end
    expect(page.at("#flash").text).to include("Garment search provider failed")
  end

  it "redirects back with the message for HTML requests" do
    get :index
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("Garment search provider failed. Try again later.")
  end

  it "returns the message as JSON with 422" do
    get :index, format: :json
    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq("error" => "Garment search provider failed. Try again later.")
  end
end
