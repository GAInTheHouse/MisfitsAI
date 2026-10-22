# frozen_string_literal: true

module Wardrobe
  # Turbo Stream updates for a garment whose image changed (design doc 2.4: same partials as the first
  # render). Used by the image jobs. Missing targets on a page are ignored by Turbo.
  module GarmentBroadcasts
    module_function

    def image_changed(garment)
      stream = [ garment.user, :wardrobe ]
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: garment, partial: "garments/garment",
                                                         locals: { garment: garment })
      Turbo::StreamsChannel.broadcast_replace_to(stream, target: ActionView::RecordIdentifier.dom_id(garment, :thumb),
                                                         partial: "garments/thumb", locals: { garment: garment })
    end
  end
end
