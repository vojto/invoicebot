class PublicAccountantInvoicesController < ApplicationController
  before_action :set_private_response_headers
  before_action :set_accountant_access, except: :open
  before_action :set_invoice_month, only: [ :show, :download, :spreadsheet ]

  def open
    access = AccountantAccess.authenticate(params[:access_token])
    raise ActiveRecord::RecordNotFound unless access

    month = parse_month(params[:month].presence || Date.current.strftime("%Y-%m"))

    redirect_to accountant_month_path(
      month: month.strftime("%Y-%m"),
      access_token: access.public_token
    )
  end

  def show
    @accountant_access.touch(:last_accessed_at)
    invoices = ordered_monthly_invoices
    invoice_table = accountant_invoice_table(invoices)

    render inertia: "accountant/invoices/show", props: {
      invoice_month: serialize_month(@invoice_month),
      progress_storage_key: progress_storage_key,
      previous_month_url: accountant_month_path(
        month: @invoice_month.prev_month.strftime("%Y-%m"),
        access_token: @accountant_access.public_token
      ),
      next_month_url: accountant_month_path(
        month: @invoice_month.next_month.strftime("%Y-%m"),
        access_token: @accountant_access.public_token
      ),
      download_url: accountant_month_download_path(
        month: @invoice_month.strftime("%Y-%m"),
        access_token: @accountant_access.public_token
      ),
      spreadsheet_url: accountant_month_spreadsheet_path(
        month: @invoice_month.strftime("%Y-%m"),
        access_token: @accountant_access.public_token
      ),
      table: {
        columns: invoice_table.columns,
        rows: invoice_table.rows
      },
      invoices: invoices.map { |invoice| serialize_invoice(invoice) }
    }
  end

  def download
    invoices = monthly_invoices.includes(pdf_attachment: :blob)
    return head :not_found if invoices.empty?

    send_data InvoiceZip.new(invoices).call,
      filename: "invoices-#{@invoice_month.strftime('%Y-%m')}.zip",
      type: "application/zip",
      disposition: "attachment"
  end

  def spreadsheet
    invoices = ordered_monthly_invoices
    return head :not_found if invoices.empty?

    invoice_table = accountant_invoice_table(invoices)

    send_data AccountantInvoiceSpreadsheet.new(invoice_table).call,
      filename: "invoices-#{@invoice_month.strftime('%Y-%m')}.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  def pdf
    invoice = shared_invoices.find(params[:id])
    return head :not_found unless invoice.pdf.attached?

    send_data invoice.pdf.download,
      filename: invoice.pdf.filename.to_s,
      type: invoice.pdf.content_type,
      disposition: "inline"
  end

  def pages
    invoice = shared_invoices.find(params[:id])

    render json: {
      pages: invoice.page_images.order(:page_number).map { |page_image|
        {
          page_number: page_image.page_number,
          image_url: accountant_invoice_page_path(
            id: invoice.id,
            page_number: page_image.page_number,
            access_token: @accountant_access.public_token
          )
        }
      }
    }
  end

  def page
    invoice = shared_invoices.find(params[:id])
    page_image = invoice.page_images.find_by!(page_number: params[:page_number])
    return head :not_found unless page_image.image.attached?

    send_data page_image.image.download,
      filename: page_image.image.filename.to_s,
      type: page_image.image.content_type,
      disposition: "inline"
  end

  private

  def set_private_response_headers
    response.set_header("Cache-Control", "private, no-store")
    response.set_header("Referrer-Policy", "no-referrer")
    response.set_header("X-Robots-Tag", "noindex, nofollow, noarchive")
  end

  def set_accountant_access
    @accountant_access = AccountantAccess.authenticate(params[:access_token])
    raise ActiveRecord::RecordNotFound unless @accountant_access
  end

  def set_invoice_month
    @invoice_month = parse_month(params[:month])
  end

  def parse_month(value)
    month = value.to_s
    raise ActiveRecord::RecordNotFound unless month.match?(/\A\d{4}-\d{2}\z/)

    Date.strptime(month, "%Y-%m")
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end

  def shared_invoices
    @accountant_access.user.invoices.where(deleted_at: nil)
  end

  def monthly_invoices
    shared_invoices.where(accounting_date: @invoice_month..@invoice_month.end_of_month)
  end

  def ordered_monthly_invoices
    monthly_invoices
      .order(accounting_date: :asc, created_at: :asc)
      .includes(:category, bank_transaction: :bank_connection, pdf_attachment: :blob)
  end

  def accountant_invoice_table(invoices)
    AccountantInvoiceTable.new(
      invoices,
      pdf_url: ->(invoice) {
        invoice.pdf.attached? ? accountant_invoice_pdf_url(
          id: invoice.id,
          access_token: @accountant_access.public_token
        ) : nil
      }
    )
  end

  def serialize_month(month)
    {
      key: month.strftime("%Y-%m"),
      label: month.strftime("%B %Y")
    }
  end

  def serialize_invoice(invoice)
    transaction = invoice.bank_transaction

    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_cents: invoice.amount_cents,
      currency: invoice.currency,
      accounting_date: invoice.accounting_date&.iso8601,
      issue_date: invoice.issue_date&.iso8601,
      delivery_date: invoice.delivery_date&.iso8601,
      category_name: invoice.category&.name,
      vendor_country: invoice.vendor_country,
      vendor_eu_vat_id: invoice.vendor_eu_vat_id,
      transaction: transaction ? {
        date: (transaction.booking_date || transaction.value_date)&.iso8601,
        account_name: transaction.bank_connection.institution_name.presence,
        amount_cents: transaction.amount_cents,
        currency: transaction.currency,
        original_amount_cents: transaction.original_amount_cents,
        original_currency: transaction.original_currency,
        direction: transaction.direction
      } : nil,
      pdf_url: invoice.pdf.attached? ? accountant_invoice_pdf_path(
        id: invoice.id,
        access_token: @accountant_access.public_token
      ) : nil,
      pages_url: invoice.pdf.attached? ? accountant_invoice_pages_path(
        id: invoice.id,
        access_token: @accountant_access.public_token
      ) : nil
    }
  end

  def progress_storage_key
    Digest::SHA256.hexdigest("#{@accountant_access.id}:#{@accountant_access.token_digest}").first(16)
  end
end
