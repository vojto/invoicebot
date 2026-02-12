class StatementsController < ApplicationController
  before_action :require_authentication
  before_action :set_statement_month

  def show
    primary_transactions = transactions_scope
      .where(booking_date: @month_range)
      .order(booking_date: :asc, created_at: :asc)
      .to_a

    month_invoices = current_user.invoices
      .where(deleted_at: nil, accounting_date: @month_range)
      .order(accounting_date: :desc, created_at: :desc)
      .to_a

    linked_transactions = transactions_scope
      .where(invoice_id: month_invoices.map(&:id))
      .to_a

    linked_transactions_by_invoice_id = linked_transactions.index_by(&:invoice_id)

    supplemental_transactions = linked_transactions.reject do |tx|
      transaction_date = tx.booking_date || tx.value_date
      transaction_date&.between?(@month_start, @month_end)
    end

    supplemental_sections = build_supplemental_sections(supplemental_transactions)

    invoice_only_rows = month_invoices
      .reject { |invoice| linked_transactions_by_invoice_id.key?(invoice.id) }
      .map { |invoice| serialize_invoice_only_row(invoice) }

    render inertia: "statements/show", props: {
      statement_month_key: @month_key,
      statement_month_label: month_label(@month_key),
      generated_at: Time.current.iso8601,
      primary_section: {
        month_key: @month_key,
        month_label: month_label(@month_key),
        description: "Vsetky transakcie zauctovane v #{month_label(@month_key)}.",
        rows: primary_transactions.map { |tx| serialize_transaction_row(tx) }
      },
      supplemental_sections: supplemental_sections,
      invoice_only_rows: invoice_only_rows
    }
  end

  private

  def set_statement_month
    @month_key = params[:month].to_s
    @month_start = Date.strptime(@month_key, "%Y-%m")
    @month_end = @month_start.end_of_month
    @month_range = @month_start..@month_end
  rescue ArgumentError
    head :not_found
  end

  def transactions_scope
    @transactions_scope ||= Transaction
      .joins(:bank_connection)
      .includes(:bank_connection, :invoice)
      .where(bank_connections: { user_id: current_user.id })
  end

  def build_supplemental_sections(transactions)
    grouped = transactions.group_by { |tx| month_key(tx.booking_date || tx.value_date) }

    sorted_keys = grouped.keys.sort do |a, b|
      if a == "unknown"
        1
      elsif b == "unknown"
        -1
      else
        a <=> b
      end
    end

    sorted_keys.map do |key|
      section_transactions = grouped[key].sort_by do |tx|
        date = tx.booking_date || tx.value_date
        [ date ? date.jd : 9_999_999, tx.created_at.to_i ]
      end

      {
        month_key: key,
        month_label: month_label(key),
        description: "Transakcie pre faktury zauctovane v #{month_label(@month_key)}.",
        rows: section_transactions.map { |tx| serialize_transaction_row(tx) }
      }
    end
  end

  def serialize_transaction_row(transaction)
    invoice = transaction.invoice

    {
      key: "tx-#{transaction.id}",
      transaction_id: transaction.id,
      invoice_id: invoice&.id,
      bank_name: transaction.bank_connection.institution_name.presence || "—",
      accounting_date_label: format_date(invoice&.accounting_date),
      transaction_date_label: format_date(transaction.booking_date || transaction.value_date),
      amount_label: format_amount(transaction.amount_cents, transaction.currency),
      original_amount_label: transaction.original_amount_cents && transaction.original_currency ? format_amount(transaction.original_amount_cents, transaction.original_currency) : "—",
      vendor_label: vendor_label_for(transaction, invoice),
      invoice_label: invoice ? invoice_label(invoice) : "CHYBA FAKTURA",
      hidden: transaction.hidden_at.present?,
      invoice_missing: invoice.nil?,
      transaction_missing: false
    }
  end

  def serialize_invoice_only_row(invoice)
    {
      key: "invoice-#{invoice.id}",
      transaction_id: nil,
      invoice_id: invoice.id,
      bank_name: "—",
      accounting_date_label: format_date(invoice.accounting_date),
      transaction_date_label: "—",
      amount_label: "—",
      original_amount_label: "—",
      vendor_label: vendor_label_for(nil, invoice),
      invoice_label: invoice_label(invoice),
      hidden: false,
      invoice_missing: false,
      transaction_missing: true
    }
  end

  def vendor_label_for(transaction, invoice)
    transaction&.vendor_name.presence || invoice&.vendor_name.presence || "—"
  end

  def invoice_label(invoice)
    label_parts = [ invoice.vendor_name.presence, format_amount(invoice.amount_cents, invoice.currency) ].compact
    label_parts.join(" - ")
  end

  def month_key(date)
    return "unknown" unless date

    date.strftime("%Y-%m")
  end

  def month_label(key)
    return "Neznamy datum" if key == "unknown"

    year, month = key.split("-").map(&:to_i)
    month_name = {
      1 => "januar",
      2 => "februar",
      3 => "marec",
      4 => "april",
      5 => "maj",
      6 => "jun",
      7 => "jul",
      8 => "august",
      9 => "september",
      10 => "oktober",
      11 => "november",
      12 => "december"
    }[month]

    "#{month_name} #{year}"
  end

  def format_date(date)
    return "—" unless date

    date.strftime("%-d. %-m. %Y")
  end

  def format_amount(amount_cents, currency)
    amount = amount_cents.to_f / 100
    unit = currency.presence || "EUR"

    ActiveSupport::NumberHelper.number_to_currency(amount, unit: unit, format: "%n %u")
  end
end
