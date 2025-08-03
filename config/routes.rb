Rails.application.routes.draw do
  get "static_pages/medici_home"
  get "static_pages/search_by_city"
  root to: "static_pages#medici_home"

  # devise_for :users

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
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
    end
  end

  resources :patients
  resources :results
  resources :contacts
  resources :articles
  resources :sponsors
  resources :users
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
