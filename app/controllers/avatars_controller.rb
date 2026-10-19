# frozen_string_literal: true

class AvatarsController < ApplicationController
  include ComingSoon
  def create; head :not_implemented; end
  def show; render_coming_soon(title: "Avatar"); end
end
