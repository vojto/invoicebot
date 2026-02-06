require "rails_helper"

RSpec.describe TransactionSyncService do
  let(:connection) { create(:bank_connection, sync_running: false, sync_error: "old error", sync_completed_at: nil) }

  let(:fake_requisition_data) { { "accounts" => ["acc-1"] } }

  def stub_nordigen_client(requisition_data:, account_stub:)
    fake_requisition = instance_double("Requisition")
    allow(fake_requisition).to receive(:get_requisition_by_id).and_return(requisition_data)

    fake_account = account_stub

    fake_client = instance_double("Client")
    allow(fake_client).to receive(:requisition).and_return(fake_requisition)
    allow(fake_client).to receive(:account).and_return(fake_account)

    nordigen_service = instance_double(NordigenService, client: fake_client)
    allow(NordigenService).to receive(:new).and_return(nordigen_service)
  end

  describe "#sync" do
    context "when sync succeeds" do
      let(:transaction_payload) do
        {
          "transactionId" => "tx-100",
          "internalTransactionId" => "int-100",
          "bookingDate" => "2026-02-01",
          "valueDate" => "2026-02-01",
          "transactionAmount" => { "amount" => "-12.34", "currency" => "EUR" },
          "debtorName" => "Vendor"
        }
      end

      let(:fake_account) do
        instance_double("Account").tap do |a|
          allow(a).to receive(:get_transactions).and_return(
            { "transactions" => { "booked" => [transaction_payload] } }
          )
        end
      end

      before do
        stub_nordigen_client(requisition_data: fake_requisition_data, account_stub: fake_account)
      end

      it "persists success status on bank connection and creates the transaction" do
        expect { described_class.new(connection).sync }
          .to change { connection.transactions.count }.by(1)

        connection.reload
        created_tx = connection.transactions.find_by!(internal_transaction_id: "int-100")

        expect(connection.sync_running).to eq(false)
        expect(connection.sync_error).to be_nil
        expect(connection.sync_completed_at).not_to be_nil
        expect(created_tx.amount_cents).to eq(1234)
        expect(created_tx.direction).to eq("debit")
      end
    end

    context "when sync fails" do
      let(:previous_sync_time) { 1.day.ago.change(usec: 0) }

      let(:fake_account) do
        instance_double("Account").tap do |a|
          allow(a).to receive(:get_transactions).and_raise(StandardError, "bank API unavailable")
        end
      end

      before do
        connection.update!(sync_error: nil, sync_completed_at: previous_sync_time)
        stub_nordigen_client(requisition_data: fake_requisition_data, account_stub: fake_account)
      end

      it "persists failure status on bank connection" do
        expect { described_class.new(connection).sync }
          .to raise_error(StandardError, "bank API unavailable")

        connection.reload

        expect(connection.sync_running).to eq(false)
        expect(connection.sync_error).to eq("bank API unavailable")
        expect(connection.sync_completed_at).to eq(previous_sync_time)
      end
    end
  end
end
