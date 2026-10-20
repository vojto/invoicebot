# Custom email for the owner's Shell fuel invoices. Invoice sends it after a new
# Shell invoice is created, listing every Shell invoice since August 2026, newest
# first, with each amount scaled by REIMBURSED_SHARE.
class ShellInvoicesMailer < ApplicationMailer
  VENDOR_NAME = "SHELL Slovakia, s.r.o."
  START_DATE = Date.new(2026, 8, 1)
  REIMBURSED_SHARE = 0.6

  helper_method :reimbursed_amount_cents

  def summary(invoice)
    @invoices = invoice.user.invoices
      .where(vendor_name: VENDOR_NAME, deleted_at: nil)
      .where(accounting_date: START_DATE..)
      .order(accounting_date: :desc, created_at: :desc)

    mail(to: invoice.user.email, subject: "Shell invoices since August 2026")
  end

  private

  def reimbursed_amount_cents(invoice)
    (invoice.amount_cents * REIMBURSED_SHARE).round
  end
end
