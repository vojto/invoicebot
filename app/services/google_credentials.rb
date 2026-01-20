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
      reason = force_refresh ? "force_refresh requested" : "token expired at #{user.google_token_expires_at}"
      Rails.logger.info "[GoogleCredentials] Refreshing token for #{user.email} (#{reason})"
      Rails.logger.info "[GoogleCredentials] Refresh token present: #{user.google_refresh_token.present?}, length: #{user.google_refresh_token&.length}"

      begin
        creds.refresh!
        user.update!(
          google_access_token: creds.access_token,
          google_token_expires_at: Time.at(creds.expires_at.to_i)
        )
        Rails.logger.info "[GoogleCredentials] Token refreshed successfully for #{user.email}, expires at #{user.google_token_expires_at}"
      rescue Signet::AuthorizationError => e
        Rails.logger.error "[GoogleCredentials] Failed to refresh token for #{user.email}"
        Rails.logger.error "[GoogleCredentials] Error: #{e.class}: #{e.message}"
        Rails.logger.error "[GoogleCredentials] Response body: #{e.response.body}" if e.respond_to?(:response) && e.response
        raise Google::Apis::AuthorizationError.new("Token refresh failed: #{e.message}", status_code: 401)
      end
    end
    creds
  end
end
