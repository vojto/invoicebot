# Checks that a new Shell invoice emails the owner 60% of each Shell invoice since August 2026, newest first.
require "rails_helper"

RSpec.describe ShellInvoicesMailer do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  def shell_invoice(issue_date, **attributes)
    create(:invoice, user: user, vendor_name: ShellInvoicesMailer::VENDOR_NAME, issue_date: issue_date, **attributes)
  end

  it "emails Shell invoices since August 2026 when a new one is created" do
    perform_enqueued_jobs do
      shell_invoice(Date.new(2026, 7, 31))
      shell_invoice(Date.new(2026, 8, 31), amount_cents: 18_814)
      shell_invoice(Date.new(2026, 9, 30), amount_cents: 13_263)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ user.email ])
    expect(mail.subject).to eq("Shell invoices since August 2026")
    expect(mail.text_part.body.to_s).to match(/September 2026\s+79\.58 EUR\s+August 2026\s+112\.88 EUR\s*\z/)
  end

  it "does not email for other vendors or invoices missing an amount" do
    expect {
      create(:invoice, user: user, issue_date: Date.new(2026, 8, 31))
      shell_invoice(Date.new(2026, 8, 31), amount_cents: nil)
    }.not_to have_enqueued_mail(ShellInvoicesMailer, :summary)
  end
end
