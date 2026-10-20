# frozen_string_literal: true

module Wardrobe
  class DraftsController < ApplicationController
    include ComingSoon
    def update; head :not_implemented; end
  end
end
