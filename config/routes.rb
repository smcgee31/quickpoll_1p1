Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :lti do
    get "config", to: "configuration#show", defaults: { format: :xml }, as: :configuration
    post "launch", to: "launch#create", as: :launch

    get "me", to: "sessions#show", as: :me

    resources :polls, only: %i[index create]
  end
end
