class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    invoices = Invoice
      .joins(:email)
      .where(emails: { user_id: current_user.id })
      .order(Arel.sql("COALESCE(invoices.issue_date, emails.date::date) DESC NULLS LAST"))
      .limit(100)
      .includes(email: { attachments: { file_attachment: :blob } })

    render inertia: "dashboard/show", props: {
      invoices: invoices.map { |invoice| serialize_invoice(invoice) }
    }
  end

  private

  def serialize_invoice(invoice)
    pdf_attachment = invoice.email.attachments.find(&:file_type_pdf?)
    pdf_url = pdf_attachment&.file&.attached? ? url_for(pdf_attachment.file) : nil

    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_cents: invoice.amount_cents,
      currency: invoice.currency,
      accounting_date: invoice.accounting_date&.iso8601,
      deleted_at: invoice.deleted_at&.iso8601,
      note: invoice.note,
      pdf_url: pdf_url,
      email: {
        id: invoice.email.id,
        subject: invoice.email.subject,
        from_name: invoice.email.from_name,
        from_address: invoice.email.from_address,
        date: invoice.email.date&.iso8601
      }
    }
  end
end
