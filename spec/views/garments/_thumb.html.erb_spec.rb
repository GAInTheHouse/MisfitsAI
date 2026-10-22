# frozen_string_literal: true

require "rails_helper"

# garments/_thumb is a contract for Phases 3 and 4 (design doc 6.3, 10.1): one stable id per garment.
RSpec.describe "garments/_thumb" do
  it "renders the placeholder with a stable dom id when there is no image" do
    garment = create(:garment, :bottom, name: "Khaki Chinos")
    render partial: "garments/thumb", locals: { garment: garment }
    expect(rendered).to have_css(%(img#thumb_garment_#{garment.id}[alt="Khaki Chinos"]))
    expect(rendered).to match(%r{src="/assets/placeholders/bottom-\h+\.jpg"})
  end

  it "renders the thumb variant path when there is an image" do
    garment = create(:garment, :with_image)
    render partial: "garments/thumb", locals: { garment: garment, class: "rounded" }
    expect(rendered).to have_css(%(img#thumb_garment_#{garment.id}.rounded))
    expect(rendered).to include(%(src="/rails/active_storage/representations/redirect/))
  end
end
