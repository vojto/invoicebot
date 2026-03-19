require "rails_helper"

RSpec.describe "POST /transactions/:id/upload_invoice", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }
  let(:transaction) { create(:transaction, bank_connection: connection) }

  before { sign_in(user) }

  it "creates and links an uploaded invoice to the transaction" do
    invoice = create(:invoice, user: user)
    processing_service = instance_double(InvoiceProcessingService)

    allow(InvoiceProcessingService).to receive(:new).and_return(processing_service)
    expect(processing_service).to receive(:extract_invoice_from_pdf).with(
      user,
      instance_of(Tempfile),
      filename: "invoice.pdf"
    ).and_return(invoice)

    post "/transactions/#{transaction.id}/upload_invoice", params: {
      file: uploaded_file(filename: "invoice.pdf", content_type: "application/octet-stream")
    }

    expect(response).to redirect_to("/transactions")
    expect(transaction.reload.invoice).to eq(invoice)
  end

  it "rejects non-pdf uploads" do
    expect(InvoiceProcessingService).not_to receive(:new)

    post "/transactions/#{transaction.id}/upload_invoice", params: {
      file: uploaded_file(filename: "notes.txt", content_type: "text/plain")
    }

    expect(response).to have_http_status(:bad_request)
    expect(transaction.reload.invoice).to be_nil
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
