class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    invoices = current_user.invoices
      .left_joins(:email)
      .order(Arel.sql("COALESCE(invoices.issue_date, emails.date::date) DESC NULLS LAST"))
      .limit(100)
      .includes(:email, pdf_attachment: :blob)

    render inertia: "dashboard/show", props: {
      invoices: invoices.map { |invoice| serialize_invoice(invoice) },
      last_synced_at: format_last_synced(current_user.last_synced_at),
      last_sync_error: current_user.last_sync_error
    }
  end

  private

  def format_last_synced(time)
    return "Never" if time.nil?
    time.strftime("%b %d, %Y at %l:%M %p")
  end

  def serialize_invoice(invoice)
    email = invoice.email

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
      } : nil
    }
  end
end
