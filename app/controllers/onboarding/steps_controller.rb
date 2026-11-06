# frozen_string_literal: true

module Onboarding
  class StepsController < ApplicationController
    skip_before_action :require_onboarding!

    def show
      return redirect_to wardrobe_path if current_user.onboarding_complete?

      @step = current_user.onboarding_step
      render_step(@step)
    end

    def update
      return redirect_to wardrobe_path if current_user.onboarding_complete?
      @step = current_user.onboarding_step

      case @step
      when 0 then handle_step_0
      when 1 then handle_step_1
      when 2 then handle_step_2
      when 3 then handle_step_3
      when 4 then handle_step_4
      else redirect_to onboarding_path
      end
    end

    def back
      step = [ current_user.onboarding_step - 1, 0 ].max
      current_user.update!(onboarding_step: step)
      redirect_to onboarding_path
    end

    private

    def handle_step_0
      profile = current_user.profile
      profile.assign_attributes(step0_params)
      if profile.valid?
        profile.save!
        if (m_params = measurement_params).any? { |_, v| v.present? }
          m = current_user.body_measurement || current_user.build_body_measurement
          m.update(m_params)
        end
        advance_to(1)
      else
        @profile = profile
        render_step(0)
      end
    end

    def handle_step_1
      profile = current_user.profile
      profile.assign_attributes(step1_params)
      profile.save!
      advance_to(2)
    end

    def handle_step_2
      session[:onboarding_catalog] = Array(params[:catalog_ids])
      advance_to(3)
    end

    def handle_step_3
      catalog_ids = Array(session[:onboarding_catalog])
      catalog     = ::Options.fetch(:starter_catalog).map(&:stringify_keys).select { |i| catalog_ids.include?(i["id"]) }

      custom_items = params.fetch(:custom_items, {}).values.map do |ci|
        ci.permit(:name, :category, :color, :size, :formality, :seasonality).to_h
      end

      reviewed = params.fetch(:reviewed_items, {}).values.map do |ri|
        ri.permit(:id, :name, :color, :size, :formality, :seasonality).to_h
      end

      items = build_items(catalog, reviewed, custom_items)

      if items.empty?
        flash.now[:alert] = "Add at least one item to continue."
        @step = 3
        render_step(3)
        return
      end

      Wardrobe::StarterImport.call(user: current_user, items: items)
      plan = Planner::WeekPlanner.ensure_week!(user: current_user)
      Planner::WeekPlanner.apply_demo_week!(plan)
      Planner::WeekPlanner.generate!(user: current_user, week_plan: plan)

      advance_to(4)
    end

    def handle_step_4
      current_user.update!(onboarding_completed_at: Time.current, onboarding_step: 4)
      redirect_to wardrobe_path, notice: "Welcome to your wardrobe!"
    end

    def build_items(catalog, reviewed, custom_items)
      catalog_by_id = catalog.index_by { |i| i["id"] }
      result = []

      reviewed.each do |row|
        base = catalog_by_id[row["id"]] || {}
        result << base.merge(row.compact_blank)
      end

      custom_items.each do |item|
        next if item["name"].blank? || item["category"].blank?

        result << item
      end

      result
    end

    def advance_to(step)
      current_user.update!(onboarding_step: step)
      redirect_to onboarding_path
    end

    def render_step(step)
      @profile     ||= current_user.profile
      @measurement ||= current_user.body_measurement || BodyMeasurement.new
      @catalog       = ::Options.fetch(:starter_catalog).map(&:stringify_keys).group_by { |i| i["category"] }
      @catalog_ids   = Array(session[:onboarding_catalog])
      @week_plan     = current_user.week_plans.order(created_at: :desc).first
      render "onboarding/show"
    end

    def step0_params
      params.require(:user_profile).permit(:gender, :birthday)
    rescue ActionController::ParameterMissing
      {}
    end

    def step1_params
      params.require(:user_profile).permit(aesthetics: [], style_color_tones: [], brands: [])
    rescue ActionController::ParameterMissing
      {}
    end

    def measurement_params
      params.permit(:height_cm, :weight_kg, :chest_cm, :waist_cm, :hips_cm, :inseam_cm).to_h
    end
  end
end
