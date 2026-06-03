class InvoiceReprocessingJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice&.pdf&.attached?

    InvoiceProcessingService.new.reprocess_invoice(invoice)
  ensure
    invoice&.update!(is_reprocessing: false)
  end
end
