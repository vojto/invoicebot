require "rails_helper"

RSpec.describe "GET /invoices/:id", type: :request do
  let(:user) { create(:user) }
  let(:email) { create(:email, user: user, subject: "Invoice email") }
  let(:invoice) do
    create(
      :invoice,
      user: user,
      email: email,
      vendor_name: "Hetzner",
      amount_cents: 5365,
      currency: "EUR",
      issue_date: Date.new(2026, 1, 5),
      delivery_date: Date.new(2026, 1, 31),
      note: "Cloud hosting"
    )
  end
  let!(:transaction) do
    create(
      :transaction,
      bank_connection: create(:bank_connection, user: user, institution_name: "Fio banka"),
      invoice: invoice,
      vendor_name: "HETZNER",
      amount_cents: 5365,
      currency: "EUR",
      booking_date: Date.new(2026, 2, 2)
    )
  end

  before { sign_in(user) }

  describe "POST /invoices/upload" do
    it "redirects to the created invoice page" do
      invoice = create(:invoice, user: user, vendor_name: "Hetzner")
      processing_service = instance_double(InvoiceProcessingService)

      allow(InvoiceProcessingService).to receive(:new).and_return(processing_service)
      expect(processing_service).to receive(:extract_invoice_from_pdf).with(
        user,
        instance_of(Tempfile),
        filename: "invoice.pdf"
      ).and_return(invoice)

      post "/invoices/upload", params: {
        file: uploaded_file(filename: "invoice.pdf", content_type: "application/octet-stream")
      }

      expect(response).to redirect_to("/invoices/#{invoice.id}")
      expect(flash[:notice]).to eq("Invoice created: Hetzner")
    end
  end

  it "renders the invoice detail page with linked email and transaction data" do
    get "/invoices/#{invoice.id}", headers: inertia_headers

    expect(response).to have_http_status(:ok)

    page = response.parsed_body
    expect(page["component"]).to eq("invoices/show")

    props = page["props"]["invoice"]
    expect(props["vendor_name"]).to eq("Hetzner")
    expect(props["amount_label"]).to eq("53.65 EUR")
    expect(props["issue_date"]).to eq("2026-01-05")
    expect(props["delivery_date"]).to eq("2026-01-31")
    expect(props["is_reprocessing"]).to eq(false)
    expect(props.dig("email", "subject")).to eq("Invoice email")
    expect(props.dig("bank_transaction", "id")).to eq(transaction.id)
    expect(props.dig("bank_transaction", "amount_label")).to eq("53.65 EUR")
  end

  describe "POST /invoices/:id/reprocess" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    before do
      invoice.pdf.attach(
        io: StringIO.new("%PDF-1.4 fake invoice"),
        filename: "invoice.pdf",
        content_type: "application/pdf"
      )
    end

    it "marks the invoice as reprocessing and enqueues the job" do
      post "/invoices/#{invoice.id}/reprocess"

      expect(response).to redirect_to("/invoices/#{invoice.id}")
      expect(invoice.reload.is_reprocessing).to eq(true)
      expect(InvoiceReprocessingJob).to have_been_enqueued.with(invoice.id)
    end

    it "does not enqueue another job while already reprocessing" do
      invoice.update!(is_reprocessing: true)

      post "/invoices/#{invoice.id}/reprocess"

      expect(response).to redirect_to("/invoices/#{invoice.id}")
      expect(InvoiceReprocessingJob).not_to have_been_enqueued
    end
  end

  def inertia_headers
    {
      "X-Inertia" => "true",
      "X-Inertia-Version" => ViteRuby.digest,
      "X-Requested-With" => "XMLHttpRequest",
      "Accept" => "text/html, application/xhtml+xml"
    }
  end

  def uploaded_file(filename:, content_type:)
    tempfile = Tempfile.new([ File.basename(filename, ".*"), File.extname(filename) ])
    tempfile.binmode
    tempfile.write("%PDF-1.4 fake invoice")
    tempfile.rewind

    Rack::Test::UploadedFile.new(
      tempfile.path,
      content_type,
      original_filename: filename
    )
  end
end
