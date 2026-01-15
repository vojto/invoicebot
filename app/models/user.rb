class User < ApplicationRecord
  validates :google_uid, :email, presence: true
  validates :google_uid, uniqueness: true

  def google_credentials(scopes:)
    GoogleCredentials.build(self, scopes: scopes)
  end

  def ensure_fresh_google_credentials!(scopes:)
    GoogleCredentials.ensure_fresh!(self, scopes: scopes)
  end

  def google_token_expired?
    return true unless google_token_expires_at
    google_token_expires_at <= Time.current
  end

  def google_token_expires_soon?(within: 5.minutes)
    return true unless google_token_expires_at
    google_token_expires_at <= within.from_now
  end
end
