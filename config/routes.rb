Rails.application.routes.draw do
  get "static_pages/medici_home"
  get "static_pages/search_by_city"
  root to: "static_pages#medici_home"

  # Public, no-login "More about this study" info card (see StaticPagesController).
  get "studies/:id/about", to: "static_pages#study_details", as: :study_about

  # Public "¡Quiero participar!" — leaves contact details against a study so a
  # trial centre rep can call back. Creates no account (see
  # ParticipationRequestsController).
  get "studies/:study_id/participate", to: "participation_requests#new", as: :new_participation_request
  post "studies/:study_id/participate", to: "participation_requests#create", as: :participation_requests

  # Step 2 of the flow above: the public self-report questionnaire. The patient
  # is identified by the session stamp step 1 wrote — the :study_id in the URL
  # is cosmetic/navigational; SelfReportsController never reads identity from
  # params (see that controller).
  get "studies/:study_id/participate/questions", to: "self_reports#show", as: :study_self_report
  post "studies/:study_id/participate/questions", to: "self_reports#create"

  # Operation manual / regulatory sources / feature inventory (signed-in only).
  get "about", to: "static_pages#about", as: :about

  # devise_for :users

  # No registrations: User is not :registerable (see the model). Expressing
  # interest in a study goes through ParticipationRequestsController, which
  # creates a Patient record and no account.
  devise_for :users, controllers: {
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

  # Global navbar search across studies, trial centers, reps, patients, cities.
  get "search", to: "search#index", as: :search

  # Global campaigns list (navbar) — campaigns are otherwise buried under studies.
  resources :campaigns, only: :index

  resources :patients do
    member do
      post :transition
    end
    # Capture a patient's values for a study's criteria profile + see the verdict.
    resource :criteria_assessment, only: %i[show update]
    # Patient-contributed prior exams: PDFs + pictures + notes (one bundle each).
    resource :complementary_information, only: %i[show edit update] do
      delete :purge_attachment
    end
    # One-page treatment briefing for reps/admins (eligibility + notes + info).
    resource :briefing, only: :show, controller: :patient_briefings
  end

  # Admin-only role/permission manager.
  resources :roles, only: %i[index new create edit update]
  # Admin-only account activation manager: an inactive user cannot sign in.
  resources :user_activations, only: %i[index update], path: "user-activations"
  # Admin-only country-specific configuration (e.g. the local health authority).
  resources :local_parameters, path: "local-parameters"
  resources :admins
  resources :platform_staffs
  resources :sponsor_reps
  resources :trial_center_branch_reps
  resources :results
  resources :contacts
  resources :articles
  resources :sponsors
  resources :medications
  resources :categories
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
