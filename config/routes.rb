Rails.application.routes.draw do
  get "static_pages/medici_home"
  get "static_pages/search_by_city"
  root to: "static_pages#medici_home"

  # Public, no-login "More about this study" info card (see StaticPagesController).
  get "studies/:id/about", to: "static_pages#study_details", as: :study_about

  # Operation manual / regulatory sources / feature inventory (signed-in only).
  get "about", to: "static_pages#about", as: :about

  # devise_for :users

  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  resources :trial_center_facilities do
    resources :trial_center_branches
  end

  resources :trial_center_branches
  resources :trial_cities
  resources :cities
  resources :studies do
    member do
      post :add_trial_center_branch
      delete :remove_trial_center_branch
      post :add_medication
      delete :remove_medication
      post :set_criteria_profile
      delete :unset_criteria_profile
    end

    # Promotional campaigns for a study (Campaign module). Shallow so campaigns
    # are edited/shown at /campaigns/:id; documents attach at
    # /campaigns/:campaign_id/documents and delete at /campaign_documents/:id.
    resources :campaigns, shallow: true do
      resources :campaign_documents, only: %i[ create destroy ], path: "documents"
    end
  end

  # Global campaigns list (navbar) — campaigns are otherwise buried under studies.
  resources :campaigns, only: :index

  resources :patients do
    member do
      post :transition
    end
    # Capture a patient's values for a study's criteria profile + see the verdict.
    resource :criteria_assessment, only: %i[show update]
  end

  # Admin-only role/permission manager.
  resources :roles, only: %i[index new create edit update]
  resources :admins
  resources :platform_staffs
  resources :sponsor_reps
  resources :trial_center_branch_reps
  resources :results
  resources :contacts
  resources :articles
  resources :sponsors
  resources :medications
  resources :users
  resources :criteria_profiles do
    resources :criteria_variables
  end

  # Admin-only change-control (audit) log for any PaperTrail-tracked model.
  get "change-control/:item_type/:item_id", to: "change_controls#show", as: :change_control
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
