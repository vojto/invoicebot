class TransactionsController < ApplicationController
  before_action :require_authentication
  before_action :set_transaction, only: [ :hide, :restore ]

  def index
    transactions = Transaction
      .joins(:bank_connection)
      .includes(:bank_connection)
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
    amount = amount_cents.to_f / 100
    unit = currency.presence || "EUR"

    ActiveSupport::NumberHelper.number_to_currency(amount, unit: unit, format: "%n %u")
  end
end
