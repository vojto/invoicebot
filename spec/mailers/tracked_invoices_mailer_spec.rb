# Checks that a new invoice from a tracked vendor emails the owner 60% of each
# active tracked invoice since July 2026, newest first.
require "rails_helper"

RSpec.describe TrackedInvoicesMailer do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:shell) { "SHELL Slovakia, s.r.o." }
  let(:law_firm) { "Advokátska kancelária MARIÁN VOJČÍK s.r.o." }

  def tracked_invoice(vendor_name, issue_date, **attributes)
    create(:invoice, user: user, vendor_name: vendor_name, issue_date: issue_date, **attributes)
  end

  it "emails active tracked invoices since July 2026 when a new one is created" do
    perform_enqueued_jobs do
      tracked_invoice(shell, Date.new(2026, 6, 30))
      tracked_invoice(law_firm, Date.new(2026, 7, 28), amount_cents: 201_474, deleted_at: Time.current)
      tracked_invoice(law_firm, Date.new(2026, 7, 28), amount_cents: 201_774)
      tracked_invoice(shell, Date.new(2026, 8, 31), amount_cents: 18_814)
    end

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ user.email, "vremerit@gmail.com" ])
    expect(mail.subject).to eq("Invoices 2026")
    expect(mail.text_part.body.to_s).to match(/August 2026\s+#{shell}\s+112\.88 EUR\s+July 2026\s+#{law_firm}\s+1,210\.64 EUR\s*\z/)
  end

  it "does not email for other vendors or invoices missing an amount" do
    expect {
      create(:invoice, user: user, issue_date: Date.new(2026, 8, 31))
      tracked_invoice(shell, Date.new(2026, 8, 31), amount_cents: nil)
    }.not_to have_enqueued_mail(TrackedInvoicesMailer, :summary)
  end
end
