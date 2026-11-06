# frozen_string_literal: true

class MeasurementsController < ApplicationController
  skip_before_action :require_onboarding!

  def update
    @measurement = current_user.body_measurement || current_user.build_body_measurement
    if @measurement.update(measurement_params)
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = "Saved"
          render turbo_stream: [
            turbo_stream.replace("profile_measurements", partial: "profiles/measurements",
                                 locals: { measurement: @measurement }),
            turbo_stream.update("flash", partial: "shared/flash")
          ]
        end
        format.html { redirect_to profile_path, notice: "Saved" }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("profile_measurements", partial: "profiles/measurements",
                                                    locals: { measurement: @measurement })
        end
        format.html { render "profiles/show", status: :unprocessable_entity }
      end
    end
  end

  private

  def measurement_params
    params.require(:body_measurement).permit(*BodyMeasurement::MEASUREMENT_FIELDS)
  end
end
