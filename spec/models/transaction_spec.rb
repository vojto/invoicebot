require "rails_helper"

RSpec.describe Transaction, type: :model do
  it "rejects a category owned by another user" do
    transaction = build(:transaction)
    transaction.category = create(:category)

    expect(transaction).not_to be_valid
    expect(transaction.errors[:category]).to include("must belong to the transaction owner")
  end
end
