class TransactionsController < ApplicationController
  before_action :require_authentication
  before_action :set_transaction, only: [ :hide, :restore, :invoice_matches, :link_invoice ]

  def index
    transactions = Transaction
      .joins(:bank_connection)
      .includes(:bank_connection, :invoice)
      .where(bank_connections: { user_id: current_user.id })
      .order(booking_date: :desc, created_at: :desc)
      .limit(500)

    render inertia: "transactions/index", props: {
      transaction_groups: group_transactions(transactions)
    }
  end

  def hide
    @transaction.update!(hidden_at: Time.current)
    redirect_to transactions_path
  end

  def restore
    @transaction.update!(hidden_at: nil)
    redirect_to transactions_path
  end

  def invoice_matches
    matches = invoice_match_candidates(@transaction)
    matches = sort_invoice_matches(@transaction, matches).take(5)

    render json: {
      matches: matches.map { |invoice| serialize_invoice_match(@transaction, invoice) }
    }
  end

  def link_invoice
    invoice = Invoice.find_by!(id: params[:invoice_id], user_id: current_user.id)
    Transaction.transaction do
      existing = Transaction
        .joins(:bank_connection)
        .where(bank_connections: { user_id: current_user.id })
        .find_by(invoice_id: invoice.id)

      existing&.update!(invoice_id: nil) if existing && existing.id != @transaction.id
      @transaction.update!(invoice_id: invoice.id)
    end
    redirect_to transactions_path
  end

  private

  def set_transaction
    @transaction = Transaction
      .joins(:bank_connection)
      .where(bank_connections: { user_id: current_user.id })
      .find(params[:id])
  end

  def serialize_transaction(tx)
    {
      id: tx.id,
      invoice_id: tx.invoice_id,
      invoice: tx.invoice ? serialize_invoice_summary(tx.invoice) : nil,
      direction: tx.direction,
      booking_date_label: format_date(tx.booking_date),
      amount_cents: tx.amount_cents,
      amount_label: format_amount(tx.amount_cents, tx.currency),
      original_amount_label: tx.original_amount_cents && tx.original_currency ? format_amount(tx.original_amount_cents, tx.original_currency) : "—",
      vendor_name: tx.vendor_name,
      bank_name: tx.bank_connection.institution_name,
      hidden_at: tx.hidden_at&.iso8601
    }
  end

  def group_transactions(transactions)
    grouped = transactions.group_by { |tx| month_key(tx.booking_date) }

    sorted_keys = grouped.keys.sort do |a, b|
      if a == "unknown"
        1
      elsif b == "unknown"
        -1
      else
        b <=> a
      end
    end

    sorted_keys.map do |key|
      group_transactions = grouped[key].sort do |a, b|
        if a.booking_date.nil?
          1
        elsif b.booking_date.nil?
          -1
        else
          b.booking_date <=> a.booking_date
        end
      end

      {
        month_key: key,
        month_label: month_label(key),
        transactions: group_transactions.map { |tx| serialize_transaction(tx) }
      }
    end
  end

  def serialize_invoice_summary(invoice)
    label_parts = [ invoice.vendor_name.presence, format_amount(invoice.amount_cents, invoice.currency) ].compact

    {
      id: invoice.id,
      label: label_parts.join(" - ")
    }
  end

  def serialize_invoice_match(transaction, invoice)
    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_label: format_amount(invoice.amount_cents, invoice.currency),
      date_label: format_invoice_date(invoice),
      date_offset_days: date_offset_days(transaction, invoice)
    }
  end

  def invoice_match_candidates(transaction)
    scope = Invoice.where(user_id: current_user.id, deleted_at: nil)
    matches = scope.where(currency: transaction.currency, amount_cents: transaction.amount_cents)

    if transaction.original_amount_cents.present? && transaction.original_currency.present?
      matches = matches.or(
        scope.where(
          currency: transaction.original_currency,
          amount_cents: transaction.original_amount_cents
        )
      )
    end

    matches
  end

  def sort_invoice_matches(transaction, invoices)
    invoices.sort_by do |invoice|
      offset = date_offset_days(transaction, invoice)
      offset ? offset.abs : 9_999
    end
  end

  def date_offset_days(transaction, invoice)
    transaction_date = transaction.booking_date || transaction.value_date
    invoice_date = invoice_match_date(invoice)
    return nil unless transaction_date && invoice_date

    (invoice_date - transaction_date).to_i
  end

  def invoice_match_date(invoice)
    invoice.accounting_date || invoice.issue_date || invoice.delivery_date || invoice.created_at.to_date
  end

  def format_invoice_date(invoice)
    date = invoice_match_date(invoice)
    format_date(date)
  end

  def month_key(date)
    return "unknown" unless date

    date.strftime("%Y-%m")
  end

  def month_label(key)
    return "Unknown Date" if key == "unknown"

    year, month = key.split("-").map(&:to_i)
    Date.new(year, month, 1).strftime("%B %Y")
  end

  def format_date(date)
    return "-" unless date

    date.strftime("%b %e").strip
  end

  def format_amount(amount_cents, currency)
    amount = amount_cents.to_f.abs / 100
    unit = currency.presence || "EUR"

    ActiveSupport::NumberHelper.number_to_currency(amount, unit: unit, format: "%n %u")
  end
end
