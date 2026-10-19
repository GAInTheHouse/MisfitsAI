# frozen_string_literal: true

class PagesController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :require_onboarding!

  def privacy
    render :privacy
  end

  def terms
    render :terms
  end
end
