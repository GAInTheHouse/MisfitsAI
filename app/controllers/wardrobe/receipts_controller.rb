# frozen_string_literal: true

module Wardrobe
  class ReceiptsController < ApplicationController
    include ComingSoon
    def new; render_coming_soon(title: "Receipts"); end
    def create; render_coming_soon(title: "Receipts"); end
    def show; render_coming_soon(title: "Receipts"); end
  end
end
