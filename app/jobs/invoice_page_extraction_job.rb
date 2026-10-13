class InvoicePageExtractionJob < ApplicationJob
  def perform(invoice_id)
    invoice = Invoice.find_by(id: invoice_id)
    return unless invoice&.pdf&.attached?

    # Skip if pages already exist for this blob
    current_checksum = invoice.pdf.blob.checksum
    if invoice.page_images.any?
      existing_checksum = invoice.page_images.first.image.blob&.metadata&.dig("source_checksum")
      return if existing_checksum == current_checksum
      invoice.page_images.destroy_all
    end

    Dir.mktmpdir do |dir|
      pdf_path = File.join(dir, "input.pdf")
      File.binwrite(pdf_path, invoice.pdf.download)

      output_prefix = File.join(dir, "page")
      system("pdftoppm", "-jpeg", "-r", "200", pdf_path, output_prefix, exception: true)

      Dir.glob(File.join(dir, "page-*.jpg")).sort.each do |image_path|
        # pdftoppm outputs page-01.jpg, page-02.jpg, etc.
        page_num = File.basename(image_path, ".jpg").split("-").last.to_i

        page_image = invoice.page_images.create!(page_number: page_num)
        page_image.image.attach(
          io: File.open(image_path),
          filename: "invoice_#{invoice.id}_page_#{page_num}.jpg",
          content_type: "image/jpeg",
          metadata: { source_checksum: current_checksum }
        )
      end
    end
  end
end
