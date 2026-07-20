class InvoicesController < ApplicationController
  before_action :require_authentication
  before_action :set_invoice_month, only: [ :index ]
  before_action :set_invoice, only: [ :show, :pdf, :pages, :remove, :restore, :reprocess, :update_accounting_date ]

  def index
    invoices = current_user.invoices
      .where(accounting_date: @invoice_month..@invoice_month.end_of_month)
      .order(accounting_date: :desc, created_at: :desc)
      .includes(:email, { bank_transaction: :category }, pdf_attachment: :blob)

    render inertia: "invoices/index", props: {
      invoice_month: {
        key: @invoice_month.strftime("%Y-%m"),
        label: @invoice_month.strftime("%B %Y")
      },
      invoices: invoices.map { |invoice| serialize_invoice_list_item(invoice) },
      categories: current_user.categories.order(Arel.sql("LOWER(name)")).map { |category| serialize_category(category) },
      spending_breakdowns: build_spending_breakdowns(invoices)
    }
  end

  def show
    render inertia: "invoices/show", props: {
      invoice: serialize_invoice_detail(@invoice)
    }
  end

  def pdf
    unless @invoice.pdf.attached?
      return head :not_found
    end

    send_data @invoice.pdf.download,
      filename: @invoice.pdf.filename.to_s,
      type: @invoice.pdf.content_type,
      disposition: "inline"
  end

  def pages
    page_images = @invoice.page_images.order(:page_number).includes(image_attachment: :blob)

    render json: {
      pages: page_images.map { |pi|
        {
          page_number: pi.page_number,
          image_url: url_for(pi.image)
        }
      }
    }
  end

  def remove
    @invoice.soft_delete!
    redirect_to dashboard_path
  end

  def restore
    @invoice.restore!
    redirect_to dashboard_path
  end

  def reprocess
    return redirect_to invoice_path(@invoice), alert: "Invoice has no PDF to reprocess" unless @invoice.pdf.attached?

    if @invoice.reprocess!
      redirect_to invoice_path(@invoice), notice: "Invoice reprocessing started"
    else
      redirect_to invoice_path(@invoice), alert: "Invoice is already reprocessing"
    end
  end

  def update_accounting_date
    date_string = params[:accounting_date]
    date = date_string.present? ? Date.parse(date_string) : nil
    @invoice.update!(accounting_date_override: date)
    AutomaticInvoiceMatchingService.match_invoice(@invoice.reload)
    redirect_back fallback_location: invoice_path(@invoice)
  rescue ArgumentError
    redirect_back fallback_location: invoice_path(@invoice), alert: "Invalid date format"
  end

  def upload
    file = pdf_upload_param
    return head :bad_request unless file

    processing_service = InvoiceProcessingService.new
    invoice = processing_service.extract_invoice_from_pdf(
      current_user,
      file.tempfile,
      filename: file.original_filename
    )

    if invoice
      AutomaticInvoiceMatchingService.match_invoice(invoice)
      redirect_to invoice_path(invoice), notice: "Invoice created: #{invoice.vendor_name}"
    else
      redirect_to dashboard_path, alert: "Could not extract invoice from PDF"
    end
  end

  def download
    month = params[:month]
    return head :bad_request unless month.present? && month.match?(/\A\d{4}-\d{2}\z/)

    year, month_num = month.split("-").map(&:to_i)
    start_date = Date.new(year, month_num, 1)
    end_date = start_date.end_of_month

    invoices = current_user.invoices
      .where(deleted_at: nil)
      .where(accounting_date: start_date..end_date)
      .includes(pdf_attachment: :blob)

    return head :not_found if invoices.empty?

    zip_data = create_zip(invoices)
    filename = "invoices-#{month}.zip"

    send_data zip_data, filename: filename, type: "application/zip", disposition: "attachment"
  end

  private

  def set_invoice_month
    month = params[:month].to_s
    raise ActiveRecord::RecordNotFound unless month.match?(/\A\d{4}-\d{2}\z/)

    @invoice_month = Date.strptime(month, "%Y-%m")
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end

  def set_invoice
    @invoice = current_user.invoices
      .includes(:email, :bank_transaction, pdf_attachment: :blob)
      .find(params[:id])
  end

  def serialize_invoice_list_item(invoice)
    email = invoice.email
    transaction = invoice.bank_transaction

    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_cents: invoice.amount_cents,
      currency: invoice.currency,
      accounting_date: invoice.accounting_date&.iso8601,
      deleted_at: invoice.deleted_at&.iso8601,
      note: invoice.note,
      pdf_url: invoice.pdf.attached? ? url_for(invoice.pdf) : nil,
      email: email ? {
        id: email.id,
        subject: email.subject,
        from_name: email.from_name,
        from_address: email.from_address,
        date: email.date&.iso8601
      } : nil,
      bank_transaction: transaction ? {
        id: transaction.id,
        vendor_name: transaction.vendor_name,
        category: transaction.category ? serialize_category(transaction.category) : nil
      } : nil
    }
  end

  def serialize_category(category)
    {
      id: category.id,
      name: category.name
    }
  end

  def build_spending_breakdowns(invoices)
    totals = Hash.new { |currencies, currency| currencies[currency] = Hash.new(0) }

    invoices.each do |invoice|
      transaction = invoice.bank_transaction
      next if invoice.soft_deleted? || !invoice.document_type_invoice?
      next unless transaction&.category && invoice.amount_cents.present? && invoice.currency.present?

      totals[invoice.currency][transaction.category] += invoice.amount_cents
    end

    totals.map do |currency, category_totals|
      total_amount_cents = category_totals.values.sum
      {
        currency: currency,
        total_amount_cents: total_amount_cents,
        total_amount_label: format_amount(total_amount_cents, currency),
        categories: category_totals
          .sort_by { |_, amount_cents| -amount_cents }
          .map { |category, amount_cents|
            {
              id: category.id,
              name: category.name,
              amount_cents: amount_cents,
              amount_label: format_amount(amount_cents, currency)
            }
          }
      }
    end.sort_by { |breakdown| -breakdown[:total_amount_cents] }
  end

  def serialize_invoice_detail(invoice)
    email = invoice.email
    bank_transaction = invoice.bank_transaction

    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_label: format_amount(invoice.amount_cents, invoice.currency),
      currency: invoice.currency,
      accounting_date: invoice.accounting_date&.iso8601,
      issue_date: invoice.issue_date&.iso8601,
      delivery_date: invoice.delivery_date&.iso8601,
      note: invoice.note,
      deleted_at: invoice.deleted_at&.iso8601,
      is_reprocessing: invoice.is_reprocessing,
      pdf_url: invoice.pdf.attached? ? pdf_invoice_path(invoice) : nil,
      email: email ? {
        id: email.id,
        subject: email.subject,
        from_name: email.from_name,
        from_address: email.from_address,
        date: email.date&.iso8601
      } : nil,
      bank_transaction: bank_transaction ? {
        id: bank_transaction.id,
        vendor_name: bank_transaction.vendor_name,
        amount_label: format_amount(bank_transaction.amount_cents, bank_transaction.currency),
        booking_date: bank_transaction.booking_date&.iso8601
      } : nil
    }
  end

  def format_amount(amount_cents, currency)
    return "—" if amount_cents.nil?

    amount = amount_cents.to_f / 100
    unit = currency.presence || "EUR"

    ActiveSupport::NumberHelper.number_to_currency(amount, unit: unit, format: "%n %u")
  end

  def create_zip(invoices)
    require "zip"

    buffer = Zip::OutputStream.write_buffer do |zip|
      invoices.each do |invoice|
        next unless invoice.pdf.attached?

        # Create a safe filename with date prefix, vendor name, and invoice id
        date_prefix = invoice.accounting_date.strftime("%Y-%m-%d")
        safe_vendor = (invoice.vendor_name || "unknown").gsub(/[^a-zA-Z0-9\-_]/, "_").truncate(50, omission: "")
        filename = "#{date_prefix}__#{safe_vendor}_#{invoice.id}.pdf"

        zip.put_next_entry(filename)
        zip.write(invoice.pdf.download)
      end
    end

    buffer.string
  end
end
