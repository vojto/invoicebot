require "rails_helper"

RSpec.describe "POST /transactions/:id/update_custom_note", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }
  let(:transaction) { create(:transaction, bank_connection: connection, vendor_name: "Original Vendor") }

  before { sign_in(user) }

  it "saves a custom note for the transaction" do
    post "/transactions/#{transaction.id}/update_custom_note", params: {
      custom_note: "My edited note"
    }

    expect(response).to redirect_to("/transactions")
    expect(transaction.reload.custom_note).to eq("My edited note")
    expect(transaction.reload.vendor_name).to eq("Original Vendor")
  end

  it "allows saving an empty string" do
    transaction.update!(custom_note: "Existing custom note")

    post "/transactions/#{transaction.id}/update_custom_note", params: {
      custom_note: ""
    }

    expect(response).to redirect_to("/transactions")
    expect(transaction.reload.custom_note).to eq("")
  end
end
