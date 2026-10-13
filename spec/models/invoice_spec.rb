require "rails_helper"

RSpec.describe Invoice, type: :model do
  it "normalizes a valid vendor identity" do
    invoice = create(:invoice, vendor_country: "ie", vendor_eu_vat_id: "IE 3668997OH")

    expect(invoice.vendor_country).to eq("IE")
    expect(invoice.vendor_eu_vat_id).to eq("IE3668997OH")
  end

  it "does not store an invalid EU VAT ID" do
    invoice = create(:invoice, vendor_eu_vat_id: "US123456789")

    expect(invoice.vendor_eu_vat_id).to be_nil
  end

  it "stores a non-Union scheme VAT ID" do
    invoice = create(:invoice, vendor_country: "SG", vendor_eu_vat_id: "EU 528377759")

    expect(invoice.vendor_country).to eq("SG")
    expect(invoice.vendor_eu_vat_id).to eq("EU528377759")
  end

  describe "#reprocess!" do
    around do |example|
      original_adapter = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      example.run
    ensure
      ActiveJob::Base.queue_adapter = original_adapter
    end

    it "sets the reprocessing flag and enqueues reprocessing" do
      invoice = create(:invoice)
      invoice.pdf.attach(
        io: StringIO.new("%PDF-1.4 fake invoice"),
        filename: "invoice.pdf",
        content_type: "application/pdf"
      )
      ActiveJob::Base.queue_adapter.enqueued_jobs.clear

      expect(invoice.reprocess!).to eq(true)
      expect(invoice.reload.is_reprocessing).to eq(true)
      expect(InvoiceReprocessingJob).to have_been_enqueued.with(invoice.id)
      expect(InvoicePageExtractionJob).not_to have_been_enqueued
    end

    it "does nothing without a PDF" do
      invoice = create(:invoice)

      expect(invoice.reprocess!).to eq(false)
      expect(InvoiceReprocessingJob).not_to have_been_enqueued
    end
  end
end
