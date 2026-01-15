class DashboardController < ApplicationController
  before_action :require_authentication

  def show
    invoices = Invoice
      .joins(:email)
      .where(emails: { user_id: current_user.id })
      .order(Arel.sql("COALESCE(invoices.issue_date, emails.date::date) DESC NULLS LAST"))
      .limit(100)
      .includes(:email)

    render inertia: "dashboard/show", props: {
      invoices: invoices.map { |invoice| serialize_invoice(invoice) }
    }
  end

  private

  def serialize_invoice(invoice)
    {
      id: invoice.id,
      vendor_name: invoice.vendor_name,
      amount_cents: invoice.amount_cents,
      currency: invoice.currency,
      issue_date: invoice.issue_date&.iso8601,
      delivery_date: invoice.delivery_date&.iso8601,
      note: invoice.note,
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
