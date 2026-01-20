Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication
  get "/auth/:provider/callback", to: "sessions#google_callback"
  get "/auth/failure", to: "sessions#failure"
  get "/logout", to: "sessions#logout"

  # Dashboard
  get "/dashboard", to: "dashboard#show", as: :dashboard
  post "/dashboard/sync", to: "dashboard#sync", as: :sync_dashboard

  # Transactions
  get "/transactions", to: "transactions#index", as: :transactions
  get "/transactions/:id/invoice_matches", to: "transactions#invoice_matches", as: :transaction_invoice_matches
  post "/transactions/:id/link_invoice", to: "transactions#link_invoice", as: :link_transaction_invoice
  post "/transactions/:id/update_vendor", to: "transactions#update_vendor", as: :update_transaction_vendor
  post "/transactions/:id/hide", to: "transactions#hide", as: :hide_transaction
  post "/transactions/:id/restore", to: "transactions#restore", as: :restore_transaction

  # Banks
  get "/banks", to: "banks#index", as: :banks
  post "/banks/connect", to: "banks#connect", as: :connect_banks
  get "/banks/callback", to: "banks#callback", as: :callback_banks

  # Invoices
  resources :invoices, only: [] do
    collection do
      get :download
      post :upload
    end
    member do
      post :remove
      post :restore
    end
  end

  # Defines the root path route ("/")
  root "landing#show"
end
