# Registers the :cloudflare delivery method (CloudflareEmailDelivery), which
# production uses for all emails. The settings come from the environment, see
# .env.example.
ActiveSupport.on_load(:action_mailer) do
  add_delivery_method :cloudflare, CloudflareEmailDelivery,
    account_id: ENV["CLOUDFLARE_ACCOUNT_ID"], api_token: ENV["CLOUDFLARE_EMAIL_API_TOKEN"]
end
