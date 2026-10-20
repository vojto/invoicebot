# Custom email for the owner's Shell fuel invoices. Invoice sends it after a new
# Shell invoice is created, listing all of that year's Shell invoices, newest first.
class ShellInvoicesMailer < ApplicationMailer
  VENDOR_NAME = "SHELL Slovakia, s.r.o."

  def summary(invoice)
    @year = invoice.accounting_date.year
    @invoices = invoice.user.invoices
      .where(vendor_name: VENDOR_NAME, deleted_at: nil)
      .where(accounting_date: Date.new(@year).all_year)
      .order(accounting_date: :desc, created_at: :desc)

    mail(to: invoice.user.email, subject: "Shell invoices #{@year}")
  end
end
