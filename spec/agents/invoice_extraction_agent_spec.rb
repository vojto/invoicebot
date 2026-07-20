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
        is_invoice: true,
        document_type: "invoice",
        vendor_name: "Acme",
        amount_cents: 1234,
        currency: "EUR",
        issue_date: "2026-01-15",
        delivery_date: nil,
        note: nil
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
        {
          is_invoice: true,
          document_type: "invoice",
          vendor_name: "Acme",
          amount_cents: 1234,
          currency: "EUR",
          issue_date: "2026-01-15"
        }.to_json
      )
    )

    result = agent.call

    expect(result[:vendor_name]).to eq("Acme")
    expect(result[:amount_cents]).to eq(1234)
  end

  it "extracts credit notes as a distinct document type" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(
        is_invoice: true,
        document_type: "credit_note",
        vendor_name: "Acme",
        amount_cents: 1234,
        currency: "EUR",
        issue_date: "2026-01-15"
      )
    )

    expect(agent.call[:document_type]).to eq("credit_note")
  end

  it "retries with the full PDF when the first page has no accounting date" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(is_invoice: true, vendor_name: "Acme", amount_cents: 1234, currency: "EUR"),
      llm_result(is_invoice: true, vendor_name: "Acme", amount_cents: 1234, currency: "EUR", issue_date: "2026-01-15")
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
    expect(result[:issue_date]).to eq(Date.new(2026, 1, 15))
    expect(result[:extraction_scope]).to eq("full_pdf")
  end

  it "retries with the full PDF when the first page has no total" do
    allow(schema_chat).to receive(:ask).and_return(
      llm_result(is_invoice: true, amount_cents: nil),
      llm_result(is_invoice: true, vendor_name: "Acme", amount_cents: 5678, currency: "EUR")
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
      llm_result(is_invoice: false, amount_cents: nil),
      llm_result(is_invoice: true, vendor_name: "Acme", amount_cents: 9012, currency: "EUR")
    )

    result = agent.call

    expect(schema_chat).to have_received(:ask).twice
    expect(result[:is_invoice]).to eq(true)
    expect(result[:amount_cents]).to eq(9012)
    expect(result[:extraction_scope]).to eq("full_pdf")
  end

  def llm_result(content = {})
    defaults = {
      is_invoice: true,
      document_type: nil,
      vendor_name: nil,
      amount_cents: nil,
      currency: nil,
      issue_date: nil,
      delivery_date: nil,
      note: nil
    }

    response_content = content.is_a?(String) ? content : defaults.merge(content)

    instance_double(
      RubyLLM::Message,
      content: response_content,
      input_tokens: 100,
      output_tokens: 20
    )
  end
end
