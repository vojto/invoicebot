class TransactionsController < ApplicationController
  before_action :require_authentication

  def index
    transactions = Transaction
      .joins(:bank_connection)
      .includes(:bank_connection)
      .where(bank_connections: { user_id: current_user.id })
      .order(booking_date: :desc)
      .limit(500)

    render inertia: "transactions/index", props: {
      transactions: transactions.map { |tx| serialize_transaction(tx) }
    }
  end

  private

  def serialize_transaction(tx)
    {
      id: tx.id,
      booking_date: tx.booking_date&.iso8601,
      amount_cents: tx.amount_cents,
      currency: tx.currency,
      creditor_name: tx.creditor_name,
      debtor_name: tx.debtor_name,
      description: tx.description,
      bank_name: tx.bank_connection.institution_name
    }
  end
end
