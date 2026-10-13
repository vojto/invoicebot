class InvoiceZip
  def initialize(invoices)
    @invoices = invoices
  end

  def call
    buffer = Zip::OutputStream.write_buffer do |zip|
      @invoices.each do |invoice|
        next unless invoice.pdf.attached?

        date_prefix = invoice.accounting_date.strftime("%Y-%m-%d")
        safe_vendor = (invoice.vendor_name || "unknown").gsub(/[^a-zA-Z0-9\-_]/, "_").truncate(50, omission: "")

        zip.put_next_entry("#{date_prefix}__#{safe_vendor}_#{invoice.id}.pdf")
        zip.write(invoice.pdf.download)
      end
    end

    buffer.string
  end
end
