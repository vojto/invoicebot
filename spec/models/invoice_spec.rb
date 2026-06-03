require "rails_helper"

RSpec.describe Invoice, type: :model do
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

      expect(invoice.reprocess!).to eq(true)
      expect(invoice.reload.is_reprocessing).to eq(true)
      expect(InvoiceReprocessingJob).to have_been_enqueued.with(invoice.id)
    end

    it "does nothing without a PDF" do
      invoice = create(:invoice)

      expect(invoice.reprocess!).to eq(false)
      expect(InvoiceReprocessingJob).not_to have_been_enqueued
    end
  end
end
