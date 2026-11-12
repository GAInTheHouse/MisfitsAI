# frozen_string_literal: true

# Issue #8: the user confirms (or un-confirms) wearing an outfit. Confirmed outfits are kept when the week is
# regenerated, and their pieces are deprioritised for a week (Planner::WeekPlanner.recently_worn_ids).
class OutfitWearsController < ApplicationController
  before_action :authenticate_user!

  def update
    @outfit = OutfitRecommendation.joins(:week_plan).where(week_plans: { user_id: current_user.id })
                                  .find(params[:id])
    @outfit.update!(worn_at: @outfit.worn? ? nil : Time.current)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          helpers.dom_id(@outfit, :timeline), partial: "today_outfits/segment", locals: { outfit: @outfit }
        )
      end
      format.html { redirect_to today_outfits_path(date: @outfit.date.iso8601) }
    end
  end
end
