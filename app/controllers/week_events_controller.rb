# frozen_string_literal: true

class WeekEventsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def update
    if @event.update(event_type: event_params[:event_type])
      @event.week_plan.update!(source: "manual")
      @event_options = ::Options.fetch(:event_types).map { |e| [ e[:key], e[:label] ] }
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@event),
            partial: "week_plans/day_row",
            locals: { event: @event, event_options: @event_options }
          )
        end
        format.html { redirect_to week_plan_path }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def set_event
    @event = WeekEvent.joins(:week_plan).find_by!(id: params[:id], week_plans: { user_id: current_user.id })
  end

  def event_params
    params.require(:week_event).permit(:event_type)
  end
end
