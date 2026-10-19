# frozen_string_literal: true

module Onboarding
  class StepsController < ApplicationController
    include ComingSoon
    skip_before_action :require_onboarding!
    def show; render_coming_soon(title: "Onboarding"); end
    def update; render_coming_soon(title: "Onboarding"); end
    def back; redirect_to onboarding_path; end
  end
end
