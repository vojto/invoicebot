class InvoicesController < ApplicationController
  before_action :require_authentication
  before_action :set_invoice, only: [ :show, :pdf, :pages, :remove, :restore, :update_accounting_date ]

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

  def update_accounting_date
    date_string = params[:accounting_date]
    date = date_string.present? ? Date.parse(date_string) : nil
    @invoice.update!(accounting_date_override: date)
    redirect_to dashboard_path
  rescue ArgumentError
    redirect_to dashboard_path, alert: "Invalid date format"
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
      redirect_to dashboard_path, notice: "Invoice created: #{invoice.vendor_name}"
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

  def set_invoice
    @invoice = current_user.invoices
      .includes(:email, :bank_transaction, pdf_attachment: :blob)
      .find(params[:id])
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
        safe_vendor = invoice.vendor_name.gsub(/[^a-zA-Z0-9\-_]/, "_").truncate(50, omission: "")
        filename = "#{date_prefix}__#{safe_vendor}_#{invoice.id}.pdf"

        zip.put_next_entry(filename)
        zip.write(invoice.pdf.download)
      end
    end

    buffer.string
  end
end
