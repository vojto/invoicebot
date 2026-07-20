require "rails_helper"

RSpec.describe AutomaticInvoiceMatchingService do
  subject(:service) { described_class.new }

  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }

  it "automatically links a unique exact match within two days" do
    transaction = create(:transaction, bank_connection: connection, amount_cents: 5_000, currency: "EUR", booking_date: Date.new(2026, 7, 10))
    invoice = create(:invoice, user: user, amount_cents: 5_000, currency: "EUR", issue_date: Date.new(2026, 7, 12))

    expect(service.match_transaction(transaction)).to eq(invoice)
    expect(transaction.reload).to have_attributes(invoice: invoice, invoice_match_source: "automatic")
  end

  it "matches against the transaction's original amount and currency" do
    transaction = create(
      :transaction,
      bank_connection: connection,
      amount_cents: 4_300,
      currency: "EUR",
      original_amount_cents: 5_000,
      original_currency: "USD",
      booking_date: Date.new(2026, 7, 10)
    )
    invoice = create(:invoice, user: user, amount_cents: 5_000, currency: "USD", issue_date: Date.new(2026, 7, 9))

    expect(service.match_invoice(invoice)).to eq(invoice)
    expect(transaction.reload.invoice).to eq(invoice)
  end

  it "does not link matches more than two days apart" do
    transaction = create(:transaction, bank_connection: connection, amount_cents: 5_000, currency: "EUR", booking_date: Date.new(2026, 7, 10))
    create(:invoice, user: user, amount_cents: 5_000, currency: "EUR", issue_date: Date.new(2026, 7, 13))

    expect { service.match_transaction(transaction) }.not_to change(transaction.reload, :invoice_id)
  end

  it "leaves ambiguous matches for manual review" do
    transaction = create(:transaction, bank_connection: connection, amount_cents: 5_000, currency: "EUR", booking_date: Date.new(2026, 7, 10))
    create_list(:invoice, 2, user: user, amount_cents: 5_000, currency: "EUR", issue_date: Date.new(2026, 7, 10))

    expect { service.match_transaction(transaction) }.not_to change(transaction.reload, :invoice_id)
  end

  it "does not match ordinary invoices to credit transactions" do
    invoice = create(:invoice, user: user, amount_cents: 5_000, currency: "EUR", issue_date: Date.new(2026, 7, 10))
    credit = create(:transaction, bank_connection: connection, direction: :credit, amount_cents: 5_000, currency: "EUR", booking_date: Date.new(2026, 7, 10))

    expect { service.match_transaction(credit) }.not_to change(credit.reload, :invoice_id)
    expect(invoice.reload.bank_transaction).to be_nil
  end


  it "matches credit notes only to credit transactions" do
    credit = create(:transaction, bank_connection: connection, direction: :credit, amount_cents: 5_000, currency: "EUR", booking_date: Date.new(2026, 7, 10))
    credit_note = create(:invoice, user: user, document_type: :credit_note, amount_cents: 5_000, currency: "EUR", issue_date: Date.new(2026, 7, 10))

    expect(service.match_invoice(credit_note)).to eq(credit_note)
    expect(credit.reload.invoice).to eq(credit_note)
  end
end
