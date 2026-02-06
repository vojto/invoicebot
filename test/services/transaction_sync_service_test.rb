require "test_helper"

class TransactionSyncServiceTest < ActiveSupport::TestCase
  class FakeRequisition
    def initialize(response)
      @response = response
    end

    def get_requisition_by_id(_requisition_id)
      @response
    end
  end

  class FakeAccount
    def initialize(response: nil, error: nil)
      @response = response
      @error = error
    end

    def get_transactions(date_from:, date_to:)
      raise @error if @error

      @response
    end
  end

  class FakeClient
    attr_reader :requisition

    def initialize(requisition:, account:)
      @requisition = requisition
      @account = account
    end

    def account(_account_id)
      @account
    end
  end

  test "sync persists success status on bank connection" do
    connection = bank_connections(:one)
    connection.update!(sync_running: false, sync_error: "old error", sync_completed_at: nil)

    transaction_payload = {
      "transactionId" => "tx-100",
      "internalTransactionId" => "int-100",
      "bookingDate" => "2026-02-01",
      "valueDate" => "2026-02-01",
      "transactionAmount" => {
        "amount" => "-12.34",
        "currency" => "EUR"
      },
      "debtorName" => "Vendor"
    }

    fake_client = FakeClient.new(
      requisition: FakeRequisition.new({ "accounts" => [ "acc-1" ] }),
      account: FakeAccount.new(
        response: {
          "transactions" => {
            "booked" => [ transaction_payload ]
          }
        }
      )
    )

    with_stubbed_nordigen_client(fake_client) do
      assert_difference -> { connection.transactions.count }, 1 do
        TransactionSyncService.new(connection).sync
      end
    end

    connection.reload
    created_tx = connection.transactions.find_by!(internal_transaction_id: "int-100")

    assert_equal false, connection.sync_running
    assert_nil connection.sync_error
    assert_not_nil connection.sync_completed_at
    assert_equal "debit", created_tx.direction
  end

  test "sync persists failure status on bank connection" do
    connection = bank_connections(:one)
    previous_sync_time = 1.day.ago.change(usec: 0)
    connection.update!(sync_running: false, sync_error: nil, sync_completed_at: previous_sync_time)

    fake_client = FakeClient.new(
      requisition: FakeRequisition.new({ "accounts" => [ "acc-1" ] }),
      account: FakeAccount.new(error: StandardError.new("bank API unavailable"))
    )

    error = assert_raises(StandardError) do
      with_stubbed_nordigen_client(fake_client) do
        TransactionSyncService.new(connection).sync
      end
    end

    connection.reload

    assert_equal "bank API unavailable", error.message
    assert_equal false, connection.sync_running
    assert_equal "bank API unavailable", connection.sync_error
    assert_equal previous_sync_time, connection.sync_completed_at
  end

  private

  def with_stubbed_nordigen_client(fake_client)
    original_new = NordigenService.method(:new)
    NordigenService.singleton_class.send(:define_method, :new) do |_user|
      Struct.new(:client).new(fake_client)
    end

    yield
  ensure
    NordigenService.singleton_class.send(:define_method, :new, original_new)
  end
end
