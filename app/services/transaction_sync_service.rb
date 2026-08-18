class TransactionSyncService
  class AuthorizationExpiredError < StandardError; end

  AUTHORIZATION_EXPIRED_MESSAGE = "Bank authorization expired. Reconnect the bank account to resume syncing."
  DEFAULT_LOOKBACK_DAYS = 30
  MAX_LOOKBACK_DAYS = 90
  SYNC_OVERLAP_DAYS = 2

  def initialize(bank_connection)
    @bank_connection = bank_connection
    @user = bank_connection.user
  end

  def sync(date_from: nil, date_to: Date.current)
    return unless @bank_connection.linked?

    date_from ||= sync_start_date
    @bank_connection.update!(sync_running: true, sync_error: nil)

    begin
      client = NordigenService.new(@user).client
      requisition_data = client.requisition.get_requisition_by_id(@bank_connection.requisition_id)

      requisition_data["accounts"].each do |account_id|
        sync_account(client, account_id, date_from: date_from, date_to: date_to)
      end

      @bank_connection.update!(sync_running: false, sync_completed_at: Time.current, sync_error: nil)
    rescue => e
      attributes = { sync_running: false, sync_error: e.message }
      attributes[:status] = :expired if e.is_a?(AuthorizationExpiredError)
      @bank_connection.update(attributes)
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

  def sync_account(client, account_id, date_from:, date_to:)
    account = client.account(account_id)

    response = account.get_transactions(date_from: date_from.iso8601, date_to: date_to.iso8601)
    transactions = booked_transactions(response)

    transactions.each do |tx|
      upsert_transaction(tx)
    end
  end

  def booked_transactions(response)
    return response.dig("transactions", "booked") || [] if response["transactions"]

    if response["status_code"] == 401 && response["detail"]&.include?("expired")
      raise AuthorizationExpiredError, AUTHORIZATION_EXPIRED_MESSAGE
    end

    message = response["detail"].presence || response["summary"].presence || "Bank returned an invalid transaction response."
    raise StandardError, message
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

    transaction = Transaction.create!(
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

    AutomaticInvoiceMatchingService.match_transaction(transaction)
  end

  def parse_amount(amount_string)
    return 0 if amount_string.blank?
    (BigDecimal(amount_string) * 100).to_i
  end

  def sync_start_date
    earliest_date = Date.current - MAX_LOOKBACK_DAYS
    last_sync_date = @bank_connection.sync_completed_at&.to_date
    requested_date = last_sync_date ? last_sync_date - SYNC_OVERLAP_DAYS : Date.current - DEFAULT_LOOKBACK_DAYS

    [ requested_date, earliest_date ].max
  end
end
