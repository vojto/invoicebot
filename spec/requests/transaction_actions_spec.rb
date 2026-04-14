require "rails_helper"

RSpec.describe "Transaction actions", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }
  let(:transaction) { create(:transaction, bank_connection: connection) }

  before { sign_in(user) }

  describe "POST /transactions/:id/flag" do
    it "flags the transaction and redirects back to the list" do
      post "/transactions/#{transaction.id}/flag"

      expect(response).to redirect_to("/transactions")
      expect(transaction.reload.is_flagged).to be(true)
    end
  end

  describe "POST /transactions/:id/unflag" do
    it "removes the flagged state and redirects back to the list" do
      transaction.update!(is_flagged: true)

      post "/transactions/#{transaction.id}/unflag"

      expect(response).to redirect_to("/transactions")
      expect(transaction.reload.is_flagged).to be(false)
    end
  end
end
