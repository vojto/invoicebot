# Checks that a new Shell invoice emails the owner this year's Shell invoices, newest first.
require "rails_helper"

RSpec.describe ShellInvoicesMailer do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  def shell_invoice(issue_date, **attributes)
    create(:invoice, user: user, vendor_name: ShellInvoicesMailer::VENDOR_NAME, issue_date: issue_date, **attributes)
  end

  it "emails this year's Shell invoices when a new one is created" do
    perform_enqueued_jobs do
      shell_invoice(Date.new(2025, 12, 31))
      shell_invoice(Date.new(2026, 1, 31), amount_cents: 6_913)
      shell_invoice(Date.new(2026, 2, 28), amount_cents: 7_358)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ user.email ])
    expect(mail.subject).to eq("Shell invoices 2026")
    expect(mail.text_part.body.to_s).to match(/February 2026\s+73\.58 EUR\s+January 2026\s+69\.13 EUR\s*\z/)
  end

  it "does not email for other vendors or invoices missing an amount" do
    expect {
      create(:invoice, user: user, issue_date: Date.new(2026, 1, 31))
      shell_invoice(Date.new(2026, 1, 31), amount_cents: nil)
    }.not_to have_enqueued_mail(ShellInvoicesMailer, :summary)
  end
end
