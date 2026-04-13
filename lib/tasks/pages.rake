namespace :pages do
  desc "Extract page images from all invoices with attached PDFs"
  task extract_all: :environment do
    invoices = Invoice.joins(pdf_attachment: :blob).where(deleted_at: nil)
    total = invoices.count
    puts "Enqueuing page extraction for #{total} invoices..."

    invoices.find_each.with_index(1) do |invoice, i|
      InvoicePageExtractionJob.perform_later(invoice.id)
      puts "  [#{i}/#{total}] Enqueued invoice ##{invoice.id} (#{invoice.vendor_name})"
    end

    puts "Done. #{total} jobs enqueued."
  end
end
