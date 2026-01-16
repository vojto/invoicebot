class NordigenService
  TOKEN_EXPIRY_BUFFER = 5.minutes

  def initialize(user)
    @user = user
  end

  def client
    ensure_valid_token!
    client = Nordigen::NordigenClient.new(
      secret_id: ENV["NORDIGEN_SECRET_ID"],
      secret_key: ENV["NORDIGEN_SECRET_KEY"]
    )
    client.set_token(@user.nordigen_access_token)
    client
  end

  private

  def ensure_valid_token!
    if token_valid?
      return
    elsif refresh_token_available?
      refresh_access_token!
    else
      generate_new_token!
    end
  end

  def token_valid?
    @user.nordigen_access_token.present? &&
      @user.nordigen_token_expires_at.present? &&
      @user.nordigen_token_expires_at > Time.current + TOKEN_EXPIRY_BUFFER
  end

  def refresh_token_available?
    @user.nordigen_refresh_token.present?
  end

  def refresh_access_token!
    client = base_client
    token_data = client.exchange_token(@user.nordigen_refresh_token)
    update_tokens!(token_data)
  rescue => e
    Rails.logger.warn("Failed to refresh Nordigen token: #{e.message}, generating new token")
    generate_new_token!
  end

  def generate_new_token!
    client = base_client
    token_data = client.generate_token
    update_tokens!(token_data)
  end

  def base_client
    Nordigen::NordigenClient.new(
      secret_id: ENV["NORDIGEN_SECRET_ID"],
      secret_key: ENV["NORDIGEN_SECRET_KEY"]
    )
  end

  def update_tokens!(token_data)
    @user.update!(
      nordigen_access_token: token_data["access"],
      nordigen_refresh_token: token_data["refresh"],
      nordigen_token_expires_at: 24.hours.from_now
    )
  end
end
