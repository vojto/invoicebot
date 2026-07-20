require "rails_helper"

RSpec.describe Invoice, type: :model do
  it "rejects a category owned by another user" do
    invoice = build(:invoice)
    invoice.category = create(:category)

    expect(invoice).not_to be_valid
    expect(invoice.errors[:category]).to include("must belong to the invoice owner")
  end
end
