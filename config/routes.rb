Rails.application.routes.draw do
  get "static_pages/medici_home"
  get "static_pages/search_by_city"
  root to: "static_pages#medici_home"

  # devise_for :users

  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  resources :trial_center_facilities do
    resources :trial_center_branches
  end

  resources :trial_center_branches do
    member do
      post :add_rep
      delete :remove_rep
    end
  end
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
  end

  resources :patients do
    member do
      post :transition
    end
  end
  resources :admins
  resources :sponsor_reps
  resources :trial_center_branch_reps
  resources :results
  resources :contacts
  resources :articles
  resources :sponsors do
    member do
      post :add_rep
      delete :remove_rep
    end
  end
  resources :medications
  resources :users
  resources :criteria_profiles do
    resources :criteria_variables
  end
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
