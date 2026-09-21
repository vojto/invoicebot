# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceExtractionAgent do
  subject(:agent) { described_class.new(StringIO.new("%PDF-1.4"), filename: "invoice.pdf") }

  it "extracts invoice data from the PDF" do
    allow(agent).to receive(:ask).and_return(llm_result(extracted_data(amount_cents: 1234, issue_date: "2026-01-15")))

    result = agent.call

    expect(agent).to have_received(:ask)
      .with("Extract invoice data from this document.", with: an_instance_of(RubyLLM::Attachment)).once
    expect(result).to include(is_invoice: true, vendor_name: "Acme", amount_cents: 1234, issue_date: Date.new(2026, 1, 15))
  end

  it "rejects an extraction without an accounting date" do
    allow(agent).to receive(:ask).and_return(llm_result(extracted_data(issue_date: nil, delivery_date: nil)))

    expect { agent.call }.to raise_error(ApplicationAgent::InvalidResponseError)
  end

  it "extracts credit notes with their document references" do
    allow(agent).to receive(:ask).and_return(
      llm_result(
        extracted_data(
          type: "credit_note",
          document_number: "CN-2",
          referenced_invoice_number: "INV-1"
        )
      )
    )

    result = agent.call

    expect(result).to include(
      document_type: "credit_note",
      note: "Document number: CN-2; Referenced invoice: INV-1"
    )
  end

  it "extracts normalized vendor identity" do
    allow(agent).to receive(:ask).and_return(
      llm_result(extracted_data(vendor_country: nil, vendor_eu_vat_id: "SK 2120299335"))
    )

    result = agent.call

    expect(result).to include(vendor_country: "SK", vendor_eu_vat_id: "SK2120299335")
  end

  it "discards an invalid EU VAT ID" do
    allow(agent).to receive(:ask).and_return(
      llm_result(extracted_data(vendor_country: nil, vendor_eu_vat_id: "VAT-123"))
    )

    result = agent.call

    expect(result).to include(vendor_country: nil, vendor_eu_vat_id: nil)
  end

  it "returns a non-invoice result when the document is unsupported" do
    allow(agent).to receive(:ask).and_return(
      llm_result(status_data("unsupported_document"))
    )

    result = agent.call

    expect(agent).to have_received(:ask).once
    expect(result).to include(is_invoice: false, extraction_status: "unsupported_document")
  end

  def extracted_data(
    type: "invoice",
    explicit_label: "Invoice",
    vendor_name: "Acme",
    vendor_country: nil,
    vendor_eu_vat_id: nil,
    document_number: nil,
    referenced_invoice_number: nil,
    amount_cents: 1234,
    currency: "EUR",
    issue_date: "2026-01-15",
    delivery_date: nil
  )
    {
      status: "extracted",
      document: {
        type: type,
        explicit_label: explicit_label,
        vendor_name: vendor_name,
        vendor_country: vendor_country,
        vendor_eu_vat_id: vendor_eu_vat_id,
        document_number: document_number,
        referenced_invoice_number: referenced_invoice_number,
        total: {
          amount_cents: amount_cents,
          currency: currency,
          kind: type == "credit_note" ? "credit_total" : "invoice_total"
        },
        issue_date: issue_date,
        delivery_date: delivery_date
      }
    }
  end

  def status_data(status)
    { status: status, document: nil }
  end

  def llm_result(data)
    RubyLLM::Message.new(role: :assistant, content: data.to_json)
  end
end
