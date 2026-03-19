require "rails_helper"

RSpec.describe GoogleCredentials do
  describe ".build" do
    let(:scopes) { described_class::SCOPE_GMAIL }

    it "maps token expiry to credentials so expired tokens are detected" do
      token_expiry = 1.hour.ago.change(usec: 0)
      user = build(
        :user,
        google_access_token: "access-token",
        google_refresh_token: "refresh-token",
        google_token_expires_at: token_expiry
      )

      credentials = described_class.build(user, scopes: scopes)

      expect(credentials.expires_at.to_i).to eq(token_expiry.to_i)
      expect(credentials).to be_expired
    end
  end
end
