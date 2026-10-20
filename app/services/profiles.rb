# frozen_string_literal: true

module Profiles
  Context = Data.define(
    :gender, :color_tone, :favorite_colors, :avoided_colors, :skin_tone,
    :hair_style, :hair_color, :body_type, :top_size, :bottom_size, :shoe_size,
    :measurements, :avatar_attached?
  )

  module_function

  def for(user)
    profile = user.profile
    measurement = user.body_measurement
    measurements_hash = if measurement
                          BodyMeasurement::MEASUREMENT_FIELDS.index_with { |f| measurement.public_send(f) }
    end

    Context.new(
      gender: profile&.gender,
      color_tone: profile&.color_tone,
      favorite_colors: Array(profile&.favorite_colors),
      avoided_colors: Array(profile&.avoided_colors),
      skin_tone: profile&.skin_tone,
      hair_style: profile&.hair_style,
      hair_color: profile&.hair_color,
      body_type: profile&.body_type,
      top_size: profile&.top_size,
      bottom_size: profile&.bottom_size,
      shoe_size: profile&.shoe_size,
      measurements: measurements_hash,
      avatar_attached?: profile&.avatar&.attached? || false
    )
  end
end
