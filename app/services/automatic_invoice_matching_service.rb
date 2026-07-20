class AutomaticInvoiceMatchingService
  DATE_TOLERANCE_DAYS = 2

  class << self
    def match_transaction(transaction)
      new.match_transaction(transaction)
    rescue StandardError => error
      log_failure("transaction", transaction.id, error)
      nil
    end

    def match_invoice(invoice)
      new.match_invoice(invoice)
    rescue StandardError => error
      log_failure("invoice", invoice.id, error)
      nil
    end

    private

    def log_failure(record_type, record_id, error)
      Rails.logger.error(
        "[AutomaticInvoiceMatchingService] Failed to match #{record_type} #{record_id}: #{error.class} - #{error.message}"
      )
    end
  end

  def match_all
    User.find_each { |user| match_user(user) }
  end

  def match_user(user)
    Transaction
      .joins(:bank_connection)
      .where(bank_connections: { user_id: user.id })
      .where(invoice_id: nil, direction: :debit, hidden_at: nil, is_flagged: false)
      .find_each { |transaction| self.class.match_transaction(transaction) }
  end

  def match_transaction(transaction)
    transaction.with_lock do
      return unless eligible_transaction?(transaction)

      invoices = invoice_candidates(transaction).limit(2).to_a
      return unless invoices.one?

      invoice = invoices.first
      transactions = transaction_candidates(invoice).limit(2).to_a
      return unless transactions.one? && transactions.first.id == transaction.id

      transaction.update!(invoice: invoice, invoice_match_source: :automatic)
      invoice
    end
  rescue ActiveRecord::RecordNotUnique
    nil
  end

  def match_invoice(invoice)
    return unless eligible_invoice?(invoice)

    transactions = transaction_candidates(invoice).limit(2).to_a
    return unless transactions.one?

    match_transaction(transactions.first)
  end

  private

  def eligible_transaction?(transaction)
    transaction.invoice_id.nil? &&
      transaction.debit? &&
      transaction.hidden_at.nil? &&
      !transaction.is_flagged? &&
      transaction_date(transaction).present? &&
      transaction_amounts(transaction).any?
  end

  def eligible_invoice?(invoice)
    invoice.bank_transaction.nil? &&
      !invoice.soft_deleted? &&
      invoice.accounting_date.present? &&
      invoice.amount_cents.present? &&
      invoice.currency.present?
  end

  def invoice_candidates(transaction)
    date = transaction_date(transaction)
    scope = Invoice
      .where(user_id: transaction.bank_connection.user_id, deleted_at: nil)
      .where(accounting_date: (date - DATE_TOLERANCE_DAYS)..(date + DATE_TOLERANCE_DAYS))
      .where.missing(:bank_transaction)

    transaction_amounts(transaction).reduce(scope.none) do |matches, amount|
      matches.or(scope.where(amount_cents: amount[:amount_cents], currency: amount[:currency]))
    end
  end

  def transaction_candidates(invoice)
    date_range = (invoice.accounting_date - DATE_TOLERANCE_DAYS)..(invoice.accounting_date + DATE_TOLERANCE_DAYS)

    Transaction
      .joins(:bank_connection)
      .where(bank_connections: { user_id: invoice.user_id })
      .where(invoice_id: nil, direction: :debit, hidden_at: nil, is_flagged: false)
      .where("COALESCE(transactions.booking_date, transactions.value_date) BETWEEN ? AND ?", date_range.begin, date_range.end)
      .where(
        <<~SQL.squish,
          (transactions.currency = :currency AND transactions.amount_cents = :amount_cents)
          OR
          (transactions.original_currency = :currency AND transactions.original_amount_cents = :amount_cents)
        SQL
        currency: invoice.currency,
        amount_cents: invoice.amount_cents
      )
  end

  def transaction_date(transaction)
    transaction.booking_date || transaction.value_date
  end

  def transaction_amounts(transaction)
    [
      { amount_cents: transaction.amount_cents, currency: transaction.currency },
      { amount_cents: transaction.original_amount_cents, currency: transaction.original_currency }
    ].select { |amount| amount.values.all?(&:present?) }.uniq
  end
end
