# frozen_string_literal: true

module Wardrobe
  class SearchesController < ApplicationController
    include ComingSoon
    def new; render_coming_soon(title: "Search"); end
    def create; render_coming_soon(title: "Search"); end
    def select; render_coming_soon(title: "Search"); end
  end
end
