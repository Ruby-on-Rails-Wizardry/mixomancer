Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "about", to: "home#about", as: :about
  get "display", to: "home#display", as: :display
  get "library", to: "home#library", as: :library
  get "browser", to: "browser#show", as: :browser
  post "browser", to: "browser#go"
  post "browser/reset", to: "browser#reset", as: :reset_browser

  post "play", to: "player#play", as: :play
  post "stop", to: "player#stop", as: :stop
  post "play_item", to: "player#play_item", as: :play_item
  post "play_video", to: "player#play_video", as: :play_video
  post "seek", to: "player#seek", as: :seek
  post "replay", to: "player#replay", as: :replay
  post "forward", to: "player#forward", as: :forward
  get "now_playing", to: "player#now_playing", as: :now_playing

  resources :remotes, only: [ :index, :show ]
  post "remotes/:id/:command", to: "remotes#press", as: :press_remote, constraints: { command: /[a-z0-9_]+/ }

  root "home#index"
end

