# frozen_string_literal: true

module Wardrobe
  class PhotoIntakesController < ApplicationController
    include ComingSoon
    def new; render_coming_soon(title: "Photo intake"); end
    def create; render_coming_soon(title: "Photo intake"); end
    def show; render_coming_soon(title: "Photo intake"); end
  end
end
