# frozen_string_literal: true

module ComingSoon
  extend ActiveSupport::Concern

  def render_coming_soon(title: "Coming soon")
    render "shared/empty_state", locals: { title: title, message: "Coming soon" }
  end
end
