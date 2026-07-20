class InvoiceReprocessingJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice&.pdf&.attached?

    if InvoiceProcessingService.new.reprocess_invoice(invoice)
      AutomaticInvoiceMatchingService.match_invoice(invoice.reload)
    end
  ensure
    invoice&.update!(is_reprocessing: false)
  end
end
