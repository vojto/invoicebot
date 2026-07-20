# frozen_string_literal: true

require "rails_helper"

RSpec.describe InvoiceExtractionAgent do
  subject(:agent) { described_class.new(pdf_path: pdf_path, filename: "invoice.pdf") }

  let(:pdf_path) { Rails.root.join("tmp/invoice.pdf").to_s }
  let(:qpdf) { instance_double(Qpdf) }
  let(:chat) { instance_double(RubyLLM::Chat) }
  let(:schema_chat) { instance_double(RubyLLM::Chat) }

  before do
    allow(Qpdf).to receive(:new).with(pdf_path).and_return(qpdf)
    allow(qpdf).to receive(:extract_first_pages) do |_count, output_path:|
      output_path
    end

    allow(RubyLLM).to receive(:chat).with(
      model: described_class::MODEL,
      provider: described_class::PROVIDER
    ).and_return(chat)
    allow(chat).to receive(:with_thinking).with(effort: described_class::REASONING_EFFORT).and_return(chat)
    allow(chat).to receive(:with_instructions).with(described_class::SYSTEM_PROMPT)
    allow(chat).to receive(:with_schema).with(described_class::ResponseSchema).and_return(schema_chat)
  end

  it "extracts from the first page only when the total is found" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(
        extracted_data(
          vendor_name: "Acme",
          amount_cents: 1234,
          currency: "EUR",
          issue_date: "2026-01-15",
          delivery_date: nil
        )
      )
    )

    result = agent.call

    expect(qpdf).to have_received(:extract_first_pages).with(1, output_path: kind_of(String))
    expect(schema_chat).to have_received(:ask).once
    expect(result[:amount_cents]).to eq(1234)
    expect(result[:extraction_scope]).to eq("first_page")
  end

  it "parses a serialized structured response" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(
        extracted_data(
          vendor_name: "Acme",
          amount_cents: 1234,
          currency: "EUR",
          issue_date: "2026-01-15"
        ).to_json
      )
    )

    result = agent.call

    expect(result[:vendor_name]).to eq("Acme")
    expect(result[:amount_cents]).to eq(1234)
  end

  it "extracts credit notes as a distinct document type" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(
        extracted_data(
          type: "credit_note",
          vendor_name: "Acme",
          amount_cents: 1234,
          currency: "EUR",
          issue_date: "2026-01-15"
        )
      )
    )

    expect(agent.call[:document_type]).to eq("credit_note")
  end

  it "returns explicit document semantics" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(
        extracted_data(
          type: "credit_note",
          explicit_label: "Credit Note",
          document_number: "CN-2",
          referenced_invoice_number: "INV-1"
        )
      )
    )

    result = agent.call

    expect(result).to include(
      extraction_status: "extracted",
      amount_kind: "credit_total",
      document_label: "Credit Note",
      note: "Document number: CN-2; Referenced invoice: INV-1"
    )
  end

  it "extracts normalized vendor identity" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(extracted_data(vendor_country: nil, vendor_eu_vat_id: "SK 2120299335"))
    )

    result = agent.call

    expect(result).to include(vendor_country: "SK", vendor_eu_vat_id: "SK2120299335")
  end

  it "discards an invalid EU VAT ID" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(extracted_data(vendor_country: nil, vendor_eu_vat_id: "VAT-123"))
    )

    result = agent.call

    expect(result).to include(vendor_country: nil, vendor_eu_vat_id: nil)
  end

  it "retries with the full PDF when the first page has no accounting date" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(status_data("insufficient_data")),
      llm_result(extracted_data(issue_date: "2026-01-15"))
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
    expect(result[:issue_date]).to eq(Date.new(2026, 1, 15))
    expect(result[:extraction_scope]).to eq("full_pdf")
  end

  it "retries with the full PDF when the first page has no total" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(status_data("insufficient_data")),
      llm_result(extracted_data(amount_cents: 5678))
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
    expect(schema_chat).to have_received(:ask).with("Extract invoice data from this document.", with: pdf_path)
    expect(result[:amount_cents]).to eq(5678)
    expect(result[:input_tokens]).to eq(200)
    expect(result[:extraction_scope]).to eq("full_pdf")
  end

  it "retries with the full PDF when the first page is not recognized as an invoice" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(status_data("unsupported_document")),
      llm_result(extracted_data(amount_cents: 9012))
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
    expect(result[:is_invoice]).to eq(true)
    expect(result[:amount_cents]).to eq(9012)
    expect(result[:extraction_scope]).to eq("full_pdf")
  end

  it "returns a non-invoice result when the full document is unsupported" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(status_data("unsupported_document"))
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
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

  def llm_result(content)
    instance_double(
      RubyLLM::Message,
      content: content,
      input_tokens: 100,
      output_tokens: 20
    )
  end
end
