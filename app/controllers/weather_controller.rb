# frozen_string_literal: true

class WeatherController < ApplicationController
  include ComingSoon
  def show; render json: { stub: true }; end
end
