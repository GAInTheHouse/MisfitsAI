# frozen_string_literal: true

module Wardrobe
  # Hides a garment from (or returns it to) outfit recommendations and refreshes its card on every open
  # wardrobe page (design doc 4.2). Phase 3's outfit page calls this too.
  class SetHidden
    def self.call(user:, garment:, hidden:)
      new(user:, garment:, hidden:).call
    end

    def initialize(user:, garment:, hidden:)
      @user = user
      @garment = garment
      @hidden = ActiveModel::Type::Boolean.new.cast(hidden)
    end

    def call
      # Callers look the garment up through current_user; this guards against any that do not.
      raise ActiveRecord::RecordNotFound, "Garment not found" unless @garment.user_id == @user.id

      @garment.update!(hidden_from_recommendations: @hidden)
      Turbo::StreamsChannel.broadcast_replace_to(
        [ @user, :wardrobe ], target: @garment, partial: "garments/garment", locals: { garment: @garment }
      )
      # Planning eligibility counts visible garments only, so the wardrobe header can change too.
      Turbo::StreamsChannel.broadcast_replace_to(
        [ @user, :wardrobe ], target: "wardrobe_status", partial: "garments/status", locals: { user: @user }
      )
      @garment
    end
  end
end
