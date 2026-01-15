class GoogleCredentials
  SCOPE_GMAIL = ["https://www.googleapis.com/auth/gmail.readonly"].freeze

  def self.build(user, scopes:)
    Google::Auth::UserRefreshCredentials.new(
      client_id: ENV["GOOGLE_CLIENT_ID"],
      client_secret: ENV["GOOGLE_CLIENT_SECRET"],
      scope: scopes,
      access_token: user.google_access_token,
      refresh_token: user.google_refresh_token,
      expiration_time_millis: (user.google_token_expires_at&.to_i || 0) * 1000
    )
  end

  def self.ensure_fresh!(user, scopes:, force_refresh: false)
    creds = build(user, scopes: scopes)
    if force_refresh || creds.expired?
      begin
        creds.refresh!
        user.update!(
          google_access_token: creds.access_token,
          google_token_expires_at: Time.at(creds.expires_at.to_i)
        )
      rescue Signet::AuthorizationError => e
        Rails.logger.error "Failed to refresh Google credentials: #{e.message}"
        raise Google::Apis::AuthorizationError.new("Token refresh failed", status_code: 401)
      end
    end
    creds
  end
end
