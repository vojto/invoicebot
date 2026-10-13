class AccountantAccess < ApplicationRecord
  TOKEN_LENGTH = 20
  TOKEN_PURPOSE = "accountant-access-token"

  belongs_to :user

  validates :name, presence: true, length: { maximum: 100 }
  validates :token_digest, presence: true, uniqueness: true
  validates :token_ciphertext, presence: true

  before_validation :generate_token, on: :create

  scope :active, -> {
    where(revoked_at: nil)
      .where("expires_at IS NULL OR expires_at > ?", Time.current)
  }

  def self.authenticate(token)
    return if token.blank?

    active.find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def public_token
    @public_token ||= self.class.encryptor.decrypt_and_verify(
      token_ciphertext,
      purpose: TOKEN_PURPOSE
    )
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def rotate_token!
    generate_token
    save!
    public_token
  end

  def active?
    revoked_at.nil? && (expires_at.nil? || expires_at.future?)
  end

  def self.encryptor
    @encryptor ||= begin
      cipher = "aes-256-gcm"
      key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base)
        .generate_key(TOKEN_PURPOSE, ActiveSupport::MessageEncryptor.key_len(cipher))
      ActiveSupport::MessageEncryptor.new(key, cipher: cipher)
    end
  end

  private

  def generate_token
    @public_token = SecureRandom.alphanumeric(TOKEN_LENGTH)
    self.token_digest = self.class.digest(@public_token)
    self.token_ciphertext = self.class.encryptor.encrypt_and_sign(
      @public_token,
      purpose: TOKEN_PURPOSE
    )
  end
end
