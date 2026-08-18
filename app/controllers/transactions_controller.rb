class TransactionsController < ApplicationController
  # Expected behavior:
  # - Linking keeps invoices one-to-one across the current user's transactions.
  # - Manual PDF uploads create an Invoice record compatible with the transaction direction, attach the PDF, and link it immediately.
  #
  # Gotchas:
  # - transactions.invoice_id is unique, so relinking must clear any existing owner first.
  # - Browsers do not always send application/pdf, so we also accept .pdf filenames.
  before_action :require_authentication
  before_action :set_transaction, only: [ :show, :hide, :restore, :flag, :unflag, :update_custom_note, :invoice_matches, :search_invoices, :link_invoice, :upload_invoice, :unlink_invoice ]

  def index
    selected_month = parse_selected_month
    transactions = Transaction
      .joins(:bank_connection)
      .includes(:bank_connection, invoice: :category)
      .where(bank_connections: { user_id: current_user.id })

    if selected_month
      transactions = transactions.where(booking_date: selected_month..selected_month.end_of_month)
    end

    transactions = transactions
      .order(booking_date: :desc, created_at: :desc)
      .limit(500)

    bank_sync_statuses = current_user.bank_connections
      .order(:institution_name)

    render inertia: "transactions/index", props: {
      transaction_groups: group_transactions(transactions),
      categories: current_user.categories.order(Arel.sql("LOWER(name)")).map { |category| serialize_category(category) },
      bank_sync_statuses: bank_sync_statuses.map { |connection| serialize_bank_sync_status(connection) },
      selected_month: selected_month ? {
        key: selected_month.strftime("%Y-%m"),
        label: selected_month.strftime("%B %Y")
      } : nil
    }
  end

  def show
    render inertia: "transactions/show", props: {
      transaction: serialize_transaction_detail(@transaction)
    }
  end

  def hide
    @transaction.update!(hidden_at: Time.current)
    redirect_back fallback_location: transactions_path
  end

  def restore
    @transaction.update!(hidden_at: nil)
    redirect_back fallback_location: transactions_path
  end

  def flag
    @transaction.update!(is_flagged: true)
    redirect_back fallback_location: transactions_path
  end

  def unflag
    @transaction.update!(is_flagged: false)
    redirect_back fallback_location: transactions_path
  end

  def update_custom_note
    @transaction.update!(custom_note: params[:custom_note])
    redirect_back fallback_location: transactions_path
  end

  def invoice_matches
    matches = sort_invoice_matches(@transaction, invoice_match_candidates(@transaction)).take(5)
    match_type = "exact"

    if matches.empty?
      matches = sort_invoice_matches(@transaction, close_invoice_match_candidates(@transaction)).take(5)
      match_type = matches.any? ? "close" : nil
    end

    render json: {
      match_type: match_type,
      matches: matches.map { |invoice| serialize_invoice_match(@transaction, invoice) }
    }
  end

  def search_invoices
    query = params[:q].to_s.strip
    return render json: { matches: [] } if query.blank?

    invoices = Invoice.where(user_id: current_user.id, deleted_at: nil)
      .compatible_with_transaction(@transaction)
      .where("vendor_name ILIKE ?", "%#{Invoice.sanitize_sql_like(query)}%")
      .limit(10)

    matches = sort_invoice_matches(@transaction, invoices).take(10)
    render json: {
      matches: matches.map { |invoice| serialize_invoice_match(@transaction, invoice) }
    }
  end

  def link_invoice
    invoice = Invoice.find_by!(id: params[:invoice_id], user_id: current_user.id)

    Transaction.transaction do
      link_invoice_to_transaction!(invoice)
    end

    redirect_back fallback_location: transactions_path
  end

  def unlink_invoice
    @transaction.update!(invoice: nil)
    redirect_back fallback_location: transaction_path(@transaction), notice: "Invoice unlinked from transaction"
  end

  def upload_invoice
    file = pdf_upload_param
    return head :bad_request unless file

    processing_service = InvoiceProcessingService.new
    invoice = processing_service.extract_invoice_from_pdf(
      current_user,
      file.tempfile,
      filename: file.original_filename,
      require_extraction: false,
      fallback_date: @transaction.booking_date || @transaction.value_date,
      fallback_vendor: @transaction.custom_note.presence || @transaction.vendor_name,
      fallback_currency: @transaction.currency,
      fallback_document_type: @transaction.credit? ? :credit_note : :invoice
    )

    Transaction.transaction do
      link_invoice_to_transaction!(invoice)
    end

    redirect_to transaction_path(@transaction), notice: "Document uploaded and linked to transaction"
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
      invoice_match_source: tx.invoice_match_source,
      invoice: tx.invoice ? serialize_invoice_summary(tx.invoice) : nil,
      direction: tx.direction,
      booking_date_label: format_date(tx.booking_date),
      amount_cents: tx.amount_cents,
      currency: tx.currency,
      original_amount_cents: tx.original_amount_cents,
      original_currency: tx.original_currency,
      vendor_name: tx.vendor_name,
      custom_note: tx.custom_note,
      bank_name: tx.bank_connection.institution_name,
      hidden_at: tx.hidden_at&.iso8601,
      is_flagged: tx.is_flagged
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
      label: label_parts.join(" - "),
      category: invoice.category ? serialize_category(invoice.category) : nil
    }
  end

  def serialize_category(category)
    {
      id: category.id,
      name: category.name
    }
  end

  def serialize_invoice_match(transaction, invoice)
    amount_diff = amount_diff_for_match(transaction, invoice)
    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      document_type: invoice.document_type,
      amount_label: format_amount(invoice.amount_cents, invoice.currency),
      date_label: format_invoice_date(invoice),
      date_offset_days: date_offset_days(transaction, invoice),
      amount_diff_label: amount_diff.present? && amount_diff != 0 ? format_signed_amount(amount_diff, invoice.currency) : nil
    }
  end

  def amount_diff_for_match(transaction, invoice)
    return nil if invoice.amount_cents.nil?

    if invoice.currency == transaction.currency
      invoice.amount_cents - transaction.amount_cents
    elsif invoice.currency == transaction.original_currency && transaction.original_amount_cents.present?
      invoice.amount_cents - transaction.original_amount_cents
    end
  end

  def invoice_match_candidates(transaction)
    scope = Invoice.where(user_id: current_user.id, deleted_at: nil)
      .compatible_with_transaction(transaction)
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

  def close_invoice_match_candidates(transaction)
    scope = Invoice.where(user_id: current_user.id, deleted_at: nil)
      .compatible_with_transaction(transaction)
    matches = scope.where(
      currency: transaction.currency,
      amount_cents: (transaction.amount_cents - 500)..(transaction.amount_cents + 500)
    )

    if transaction.original_amount_cents.present? && transaction.original_currency.present?
      matches = matches.or(
        scope.where(
          currency: transaction.original_currency,
          amount_cents: (transaction.original_amount_cents - 500)..(transaction.original_amount_cents + 500)
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

  def parse_selected_month
    return if params[:month].blank?
    raise ActiveRecord::RecordNotFound unless params[:month].match?(/\A\d{4}-\d{2}\z/)

    Date.strptime(params[:month], "%Y-%m")
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
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
    return "—" if amount_cents.nil?

    amount = amount_cents.to_f / 100
    unit = currency.presence || "EUR"

    ActiveSupport::NumberHelper.number_to_currency(amount, unit: unit, format: "%n %u")
  end

  def format_signed_amount(amount_cents, currency)
    sign = amount_cents > 0 ? "+" : ""
    "#{sign}#{format_amount(amount_cents, currency)}"
  end

  def serialize_bank_sync_status(connection)
    {
      id: connection.id,
      bank_name: connection.institution_name.presence || "Bank ##{connection.id}",
      status: connection.status,
      sync_running: connection.sync_running,
      sync_completed_at: format_last_synced(connection.sync_completed_at),
      sync_error: connection.sync_error,
      reconnect_url: connection.linked? ? nil : reconnect_bank_path(connection)
    }
  end

  def format_last_synced(time)
    return "Never" if time.nil?

    time.strftime("%b %d, %Y at %l:%M %p")
  end

  def serialize_transaction_detail(tx)
    invoice = tx.invoice
    {
      id: tx.id,
      direction: tx.direction,
      booking_date: tx.booking_date&.iso8601,
      value_date: tx.value_date&.iso8601,
      amount_label: format_amount(tx.amount_cents, tx.currency),
      original_amount_label: tx.original_amount_cents && tx.original_currency ? format_amount(tx.original_amount_cents, tx.original_currency) : nil,
      vendor_name: tx.vendor_name,
      custom_note: tx.custom_note,
      description: tx.description,
      creditor_name: tx.creditor_name,
      creditor_iban: tx.creditor_iban,
      debtor_name: tx.debtor_name,
      debtor_iban: tx.debtor_iban,
      bank_name: tx.bank_connection.institution_name,
      hidden_at: tx.hidden_at&.iso8601,
      invoice: invoice ? {
        id: invoice.id,
        vendor_name: invoice.vendor_name,
        amount_label: format_amount(invoice.amount_cents, invoice.currency),
        issue_date: invoice.issue_date&.iso8601,
        pdf_url: invoice.pdf.attached? ? pdf_invoice_path(invoice) : nil
      } : nil
    }
  end

  def link_invoice_to_transaction!(invoice)
    existing = Transaction
      .joins(:bank_connection)
      .where(bank_connections: { user_id: current_user.id })
      .find_by(invoice_id: invoice.id)

    existing&.update!(invoice: nil) if existing && existing.id != @transaction.id
    @transaction.update!(invoice: invoice, invoice_match_source: :manual)
  end
end
