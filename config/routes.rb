Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Authentication
  get "/auth/:provider/callback", to: "sessions#google_callback"
  get "/auth/failure", to: "sessions#failure"
  get "/logout", to: "sessions#logout"

  # Dashboard
  get "/dashboard", to: "dashboard#show", as: :dashboard
  post "/dashboard/sync", to: "dashboard#sync", as: :sync_dashboard

  # Transactions
  get "/transactions", to: "transactions#index", as: :transactions
  get "/transactions/month/:month", to: "transactions#index", as: :monthly_transactions
  get "/transactions/:id", to: "transactions#show", as: :transaction
  get "/transactions/:id/invoice_matches", to: "transactions#invoice_matches", as: :transaction_invoice_matches
  get "/transactions/:id/search_invoices", to: "transactions#search_invoices", as: :search_transaction_invoices
  post "/transactions/:id/link_invoice", to: "transactions#link_invoice", as: :link_transaction_invoice
  post "/transactions/:id/upload_invoice", to: "transactions#upload_invoice", as: :upload_transaction_invoice
  post "/transactions/:id/unlink_invoice", to: "transactions#unlink_invoice", as: :unlink_transaction_invoice
  post "/transactions/:id/hide", to: "transactions#hide", as: :hide_transaction
  post "/transactions/:id/restore", to: "transactions#restore", as: :restore_transaction
  post "/transactions/:id/flag", to: "transactions#flag", as: :flag_transaction
  post "/transactions/:id/unflag", to: "transactions#unflag", as: :unflag_transaction
  post "/transactions/:id/update_custom_note", to: "transactions#update_custom_note", as: :update_transaction_custom_note
  patch "/transactions/:id/category", to: "transactions#update_category", as: :update_transaction_category

  # Categories
  resources :categories, only: [ :index, :create, :update, :destroy ]

  # Statements
  get "/statements/:month", to: "statements#show", as: :statement

  # Banks
  get "/banks", to: "banks#index", as: :banks
  post "/banks/connect", to: "banks#connect", as: :connect_banks
  get "/banks/callback", to: "banks#callback", as: :callback_banks

  # Invoices
  get "/invoices/month/:month", to: "invoices#index", as: :monthly_invoices
  resources :invoices, only: [ :show ] do
    collection do
      get :download
      post :upload
    end
    member do
      get :pdf
      get :pages
      post :remove
      post :restore
      post :reprocess
      post :update_accounting_date
    end
  end

  # Defines the root path route ("/")
  root "landing#show"
end
