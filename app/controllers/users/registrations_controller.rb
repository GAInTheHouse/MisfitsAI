# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    protected

    def after_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end

    def after_inactive_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end
  end
end
