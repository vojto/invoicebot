class PublicAccountantInvoicesController < ApplicationController
  before_action :set_private_response_headers
  before_action :set_accountant_access
  before_action :set_invoice_month, only: :show

  def redirect_to_current_month
    redirect_to accountant_month_path(
      access_token: params[:access_token],
      month: Date.current.strftime("%Y-%m")
    )
  end

  def show
    @accountant_access.touch(:last_accessed_at)
    invoices = shared_invoices
      .where(accounting_date: @invoice_month..@invoice_month.end_of_month)
      .order(accounting_date: :desc, created_at: :desc)
      .includes(pdf_attachment: :blob)

    render inertia: "accountant/invoices/show", props: {
      invoice_month: serialize_month(@invoice_month),
      previous_month_url: accountant_month_path(
        access_token: params[:access_token],
        month: @invoice_month.prev_month.strftime("%Y-%m")
      ),
      next_month_url: accountant_month_path(
        access_token: params[:access_token],
        month: @invoice_month.next_month.strftime("%Y-%m")
      ),
      invoices: invoices.map { |invoice| serialize_invoice(invoice) }
    }
  end

  def pdf
    invoice = shared_invoices.find(params[:id])
    return head :not_found unless invoice.pdf.attached?

    send_data invoice.pdf.download,
      filename: invoice.pdf.filename.to_s,
      type: invoice.pdf.content_type,
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
    month = params[:month].to_s
    raise ActiveRecord::RecordNotFound unless month.match?(/\A\d{4}-\d{2}\z/)

    @invoice_month = Date.strptime(month, "%Y-%m")
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end

  def shared_invoices
    @accountant_access.user.invoices.where(deleted_at: nil)
  end

  def serialize_month(month)
    {
      key: month.strftime("%Y-%m"),
      label: month.strftime("%B %Y")
    }
  end

  def serialize_invoice(invoice)
    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_cents: invoice.amount_cents,
      currency: invoice.currency,
      accounting_date: invoice.accounting_date&.iso8601,
      pdf_url: invoice.pdf.attached? ? accountant_invoice_pdf_path(
        access_token: params[:access_token],
        id: invoice.id
      ) : nil
    }
  end
end
