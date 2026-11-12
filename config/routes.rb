Rails.application.routes.draw do
  # Security (Phase 2 Step 9): Active Storage's direct-upload endpoint needs no sign-in, so anyone could create
  # blobs and get signed upload URLs to the bucket. The app never uses direct uploads; answer 404.
  match "/rails/active_storage/direct_uploads", via: :all,
                                                to: ->(_env) { [ 404, { "content-type" => "text/plain" }, [ "Not Found" ] ] }

  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks",
                                    registrations: "users/registrations" }
  root "home#show"
  get "up" => "rails/health#show", as: :rails_health_check
  get "privacy" => "pages#privacy"
  get "terms"   => "pages#terms"
  resource :onboarding, only: [ :show, :update ], controller: "onboarding/steps" do
    post :back
  end
  resource :profile,      only: [ :show, :update ]
  resource :measurements, only: [ :update ]
  patch "time_zone" => "time_zones#update"

  resource :wardrobe, only: [ :show ], controller: "garments"
  resources :garments, only: [ :new, :create, :edit, :update, :destroy ] do
    patch :hide, on: :member
    post :retry_image, on: :member
  end
  namespace :wardrobe do
    resources :searches, only: [ :new, :create ] do
      post :select, on: :collection
    end
    resources :photo_intakes, only: [ :new, :create, :show ]
    resources :intake_batches, only: [ :destroy ] do
      post :commit, on: :member
    end
    resources :drafts, only: [ :update ]
    resources :receipts, only: [ :new, :create, :show ]
  end

  resource :week_plan, only: [ :show ] do
    post :demo
    post :generate
    resources :events, only: [ :update ], controller: "week_events"
  end
  resource :calendar_sync, only: [ :create ]
  # Issue #8: a day's outfits as a timeline, and "I wore this". Declared before resources :outfits so
  # /outfits/today is not read as an outfit id.
  get "outfits/today", to: "today_outfits#show", as: :today_outfits
  patch "outfits/:id/wear", to: "outfit_wears#update", as: :wear_outfit
  resources :outfits, only: [ :index, :show ]
  get "weather" => "weather#show"

  resource :avatar, only: [ :create, :show ]
  resources :outfit_previews, only: [ :show, :create ], param: :outfit_id
  namespace :api do
    get "metrics" => "metrics#show"
  end
  namespace :admin do
    get "metrics"  => "metrics#show"
    get "ai_usage" => "ai_usage#show"
  end
end
