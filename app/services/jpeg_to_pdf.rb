# Turns an uploaded JPG invoice into a one-page A4 PDF, so photos and scans go
# through the same PDF-only pipeline (extraction, page previews, accountant ZIP).
# Used by ApplicationController#valid_pdf_upload. The image is scaled to fit the page.
class JpegToPdf
  def self.jpeg_upload?(file)
    file.content_type == "image/jpeg" || file.original_filename.to_s.downcase.end_with?(".jpg", ".jpeg")
  end

  def initialize(file)
    @file = file
  end

  def call
    tempfile = Tempfile.new([ "invoice", ".pdf" ], binmode: true)
    Prawn::Document.generate(tempfile.path, page_size: "A4", margin: 0) do |pdf|
      pdf.image @file.tempfile.path, fit: [ pdf.bounds.width, pdf.bounds.height ], position: :center, vposition: :center
    end

    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: "#{File.basename(@file.original_filename.to_s, ".*")}.pdf",
      type: "application/pdf"
    )
  end
end
