require "rails_helper"

RSpec.describe InvoiceZip do
  it "archives attached invoice PDFs with safe filenames" do
    invoice = create(:invoice, vendor_name: "Vendor / Name", issue_date: Date.new(2026, 7, 10))
    invoice.pdf.attach(io: StringIO.new("PDF data"), filename: "original.pdf", content_type: "application/pdf")

    Zip::File.open_buffer(described_class.new([ invoice ]).call) do |zip|
      expect(zip.entries.map(&:name)).to eq([ "2026-07-10__Vendor___Name_#{invoice.id}.pdf" ])
      expect(zip.entries.first.get_input_stream.read).to eq("PDF data")
    end
  end
end
