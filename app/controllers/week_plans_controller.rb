# frozen_string_literal: true

class WeekPlansController < ApplicationController
  include ComingSoon
  def show; render_coming_soon(title: "Calendar"); end
  def demo; head :not_implemented; end
  def generate; head :not_implemented; end
end
