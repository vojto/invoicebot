require "rails_helper"

RSpec.describe "Banks" do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user, status: :expired, sync_error: "Authorization expired") }
  let(:client) { instance_double("Nordigen client") }

  before do
    sign_in(user)
    allow(NordigenService).to receive(:new).and_return(instance_double(NordigenService, client: client))
  end

  describe "POST /banks/:id/reconnect" do
    it "reuses the connection and redirects to the bank authorization" do
      allow(client).to receive(:init_session).and_return(
        "id" => "new-requisition",
        "link" => "https://bank.example/authorize"
      )
      connection

      expect { post reconnect_bank_path(connection) }
        .not_to change(BankConnection, :count)

      expect(response).to have_http_status(:conflict)
      expect(response.headers["X-Inertia-Location"]).to eq("https://bank.example/authorize")

      connection.reload
      expect(connection).to be_pending
      expect(connection.requisition_id).to eq("new-requisition")
      expect(connection.reference_id).to be_present
    end
  end

  describe "GET /banks/callback" do
    it "marks the reconnected bank as syncing and enqueues a sync" do
      expect {
        get callback_banks_path(ref: connection.reference_id)
      }.to have_enqueued_job(TransactionSyncJob).with(bank_connection_id: connection.id)

      expect(response).to redirect_to(transactions_path)

      connection.reload
      expect(connection).to be_linked
      expect(connection.sync_running).to eq(true)
      expect(connection.sync_error).to be_nil
    end
  end
end
