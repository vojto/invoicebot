class TransactionSyncService
  def initialize(bank_connection)
    @bank_connection = bank_connection
    @user = bank_connection.user
  end

  def sync
    return unless @bank_connection.linked?

    @bank_connection.update!(sync_running: true, sync_error: nil)

    begin
      client = NordigenService.new(@user).client
      requisition_data = client.requisition.get_requisition_by_id(@bank_connection.requisition_id)

      requisition_data["accounts"].each do |account_id|
        sync_account(client, account_id)
      end

      @bank_connection.update!(sync_running: false, sync_completed_at: Time.current, sync_error: nil)
    rescue => e
      @bank_connection.update(sync_running: false, sync_error: e.message)
      raise
    end
  end

  def self.sync_all
    BankConnection.linked.find_each do |connection|
      new(connection).sync
    rescue => e
      Rails.logger.error("Failed to sync transactions for connection #{connection.id}: #{e.message}")
    end
  end

  private

  def sync_account(client, account_id)
    account = client.account(account_id)
    date_from = 30.days.ago.to_date.iso8601
    date_to = Date.current.iso8601

    response = account.get_transactions(date_from: date_from, date_to: date_to)
    transactions = response.dig("transactions", "booked") || []

    transactions.each do |tx|
      upsert_transaction(tx)
    end
  end

  def upsert_transaction(tx)
    internal_id = tx["internalTransactionId"]
    return if internal_id.blank?

    existing = @bank_connection.transactions.find_by(internal_transaction_id: internal_id)
    return if existing

    raw_amount = parse_amount(tx.dig("transactionAmount", "amount"))
    description = [
      tx["remittanceInformationUnstructured"],
      tx["additionalInformation"]
    ].compact.join(" - ").presence

    Transaction.create!(
      bank_connection: @bank_connection,
      transaction_id: tx["transactionId"],
      internal_transaction_id: internal_id,
      booking_date: tx["bookingDate"],
      value_date: tx["valueDate"],
      amount_cents: raw_amount.abs,
      direction: raw_amount >= 0 ? "credit" : "debit",
      currency: tx.dig("transactionAmount", "currency"),
      creditor_name: tx["creditorName"],
      creditor_iban: tx.dig("creditorAccount", "iban"),
      debtor_name: tx["debtorName"],
      debtor_iban: tx.dig("debtorAccount", "iban"),
      description: description,
      bank_transaction_code: tx["bankTransactionCode"]
    )
  end

  def parse_amount(amount_string)
    return 0 if amount_string.blank?
    (BigDecimal(amount_string) * 100).to_i
  end
end
