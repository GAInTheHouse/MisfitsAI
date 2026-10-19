# frozen_string_literal: true

module Wardrobe
  class IntakeBatchesController < ApplicationController
    include ComingSoon
    def destroy; head :not_implemented; end
    def commit; head :not_implemented; end
  end
end
