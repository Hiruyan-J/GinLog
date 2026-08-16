# == Route Map
#

Rails.application.routes.draw do
  # 確認リンク（/users/confirmation）だけ独自コントローラで処理する。
  devise_for :users, controllers: { confirmations: "users/confirmations" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  namespace :api do
    resources :brands, only: [] do
      collection do
        get :search # GET /api/brands/search?q=xxx
      end
    end
    resources :sakes, only: [] do
      collection do
        get :search # GET /api/sakes/search?brand_id=xxx&q=yyy
      end
    end
    resources :breweries, only: [] do
      collection do
        get :search # GET /api/breweries/search?q=xxx
      end
    end
  end

  resources :sake_logs, only: %i[index show new create edit update destroy]
  get "timeline", to: "timelines#index", as: :timeline

  # Defines the root path route ("/")
  root "timelines#index"

  # 開発環境で送信メールを確認する画面（/letter_opener）
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?
end
