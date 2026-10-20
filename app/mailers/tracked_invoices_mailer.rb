# Custom email for the owner's invoices from a few tracked vendors (Shell fuel and
# the law firm). Invoice sends it after a new invoice from one of them is created,
# listing every active invoice from those vendors since July 2026, newest first,
# with each amount scaled by SHARE.
class TrackedInvoicesMailer < ApplicationMailer
  VENDOR_NAMES = [
    "SHELL Slovakia, s.r.o.",
    "Advokátska kancelária MARIÁN VOJČÍK s.r.o."
  ].freeze
  START_DATE = Date.new(2026, 7, 1)
  SHARE = 0.6

  helper_method :share_amount_cents

  def summary(invoice)
    @invoices = invoice.user.invoices
      .where(vendor_name: VENDOR_NAMES, deleted_at: nil)
      .where(accounting_date: START_DATE..)
      .order(accounting_date: :desc, created_at: :desc)

    mail(to: invoice.user.email, subject: "Invoices #{invoice.accounting_date.year}")
  end

  private

  def share_amount_cents(invoice)
    (invoice.amount_cents * SHARE).round
  end
end
