# frozen_string_literal: true

class HomeController < ApplicationController
  skip_before_action :authenticate_user!, only: :show
  skip_before_action :require_onboarding!, only: :show

  def show
    if user_signed_in?
      redirect_to after_sign_in_path_for(current_user)
    else
      render :show
    end
  end
end
