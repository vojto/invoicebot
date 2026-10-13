require "rails_helper"

RSpec.describe InvoiceReprocessingJob, type: :job do
  let(:invoice) do
    create(
      :invoice,
      is_reprocessing: true,
      vendor_name: "Old Vendor",
      vendor_country: "US",
      amount_cents: 1000,
      currency: "EUR",
      issue_date: Date.new(2026, 1, 1),
      delivery_date: nil,
      note: "Old note"
    )
  end

  before do
    invoice.pdf.attach(
      io: StringIO.new("%PDF-1.4 fake invoice"),
      filename: "invoice.pdf",
      content_type: "application/pdf"
    )
  end

  it "updates extracted fields and clears the reprocessing flag" do
    agent = instance_double(InvoiceExtractionAgent)
    allow(InvoiceExtractionAgent).to receive(:new).and_return(agent)
    allow(agent).to receive(:call).and_return(
      {
        is_invoice: true,
        document_type: "credit_note",
        vendor_name: "New Vendor",
        vendor_country: "sk",
        vendor_eu_vat_id: "SK 2120299335",
        amount_cents: 2500,
        currency: "USD",
        issue_date: Date.new(2026, 2, 1),
        delivery_date: Date.new(2026, 2, 2),
        note: "New note"
      }
    )

    described_class.perform_now(invoice.id)

    invoice.reload
    expect(invoice.is_reprocessing).to eq(false)
    expect(invoice.vendor_name).to eq("New Vendor")
    expect(invoice.vendor_country).to eq("SK")
    expect(invoice.vendor_eu_vat_id).to eq("SK2120299335")
    expect(invoice.amount_cents).to eq(2500)
    expect(invoice.currency).to eq("USD")
    expect(invoice.document_type).to eq("credit_note")
    expect(invoice.issue_date).to eq(Date.new(2026, 2, 1))
    expect(invoice.delivery_date).to eq(Date.new(2026, 2, 2))
    expect(invoice.note).to eq("New note")
  end

  it "clears the reprocessing flag when extraction fails" do
    agent = instance_double(InvoiceExtractionAgent)
    allow(InvoiceExtractionAgent).to receive(:new).and_return(agent)
    allow(agent).to receive(:call).and_raise(StandardError)

    expect { described_class.perform_now(invoice.id) }.to raise_error(StandardError)

    expect(invoice.reload.is_reprocessing).to eq(false)
  end
end
