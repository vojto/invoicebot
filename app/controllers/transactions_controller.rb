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
      transactions: transactions.map { |tx| serialize_transaction(tx) }
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
      booking_date: tx.booking_date&.iso8601,
      amount_cents: tx.amount_cents,
      currency: tx.currency,
      original_amount_cents: tx.original_amount_cents,
      original_currency: tx.original_currency,
      vendor_name: tx.vendor_name,
      creditor_name: tx.creditor_name,
      debtor_name: tx.debtor_name,
      description: tx.description,
      bank_name: tx.bank_connection.institution_name,
      hidden_at: tx.hidden_at&.iso8601
    }
  end
end
