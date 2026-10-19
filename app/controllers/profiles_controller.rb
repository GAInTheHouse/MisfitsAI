# frozen_string_literal: true

class ProfilesController < ApplicationController
  include ComingSoon
  skip_before_action :require_onboarding!
  def show; render_coming_soon(title: "Profile"); end
  def update; show; end
end
