Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           ENV["GOOGLE_CLIENT_ID"],
           ENV["GOOGLE_CLIENT_SECRET"],
           {
             scope: [
               "email",
               "profile",
               "https://www.googleapis.com/auth/gmail.readonly"
             ],
             access_type: "offline",
             prompt: "consent",
             include_granted_scopes: true
           }
end

# Allow both GET and POST for OmniAuth in Rails 7+
OmniAuth.config.allowed_request_methods = [:get, :post]

OmniAuth.config.on_failure = proc { |env|
  OmniAuth::FailureEndpoint.new(env).redirect_to_failure
}
