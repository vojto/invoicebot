require "rails_helper"

RSpec.describe AccountantAccess, type: :model do
  it "generates an encrypted 20-character public token" do
    access = create(:accountant_access)

    expect(access.public_token.length).to eq(20)
    expect(access.token_ciphertext).not_to include(access.public_token)
    expect(described_class.authenticate(access.public_token)).to eq(access)
  end

  it "rejects revoked and replaced tokens" do
    access = create(:accountant_access)
    original_token = access.public_token

    replacement_token = access.rotate_token!

    expect(replacement_token).not_to eq(original_token)
    expect(described_class.authenticate(original_token)).to be_nil
    expect(described_class.authenticate(replacement_token)).to eq(access)

    access.revoke!
    expect(described_class.authenticate(replacement_token)).to be_nil
  end
end
