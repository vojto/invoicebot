class InvoicesController < ApplicationController
  before_action :require_authentication
  before_action :set_invoice, only: [ :remove, :restore ]

  def remove
    @invoice.soft_delete!
    redirect_to dashboard_path
  end

  def restore
    @invoice.restore!
    redirect_to dashboard_path
  end

  def upload
    file = params[:file]
    return head :bad_request unless file.present? && file.content_type == "application/pdf"

    processing_service = InvoiceProcessingService.new
    invoice = processing_service.extract_invoice_from_pdf(
      current_user,
      file.tempfile,
      filename: file.original_filename
    )

    if invoice
      redirect_to dashboard_path, notice: "Invoice created: #{invoice.vendor_name}"
    else
      redirect_to dashboard_path, alert: "Could not extract invoice from PDF"
    end
  end

  def download
    month = params[:month]
    return head :bad_request unless month.present? && month.match?(/\A\d{4}-\d{2}\z/)

    year, month_num = month.split("-").map(&:to_i)
    start_date = Date.new(year, month_num, 1)
    end_date = start_date.end_of_month

    invoices = current_user.invoices
      .where(deleted_at: nil)
      .where(accounting_date: start_date..end_date)
      .includes(pdf_attachment: :blob)

    return head :not_found if invoices.empty?

    zip_data = create_zip(invoices)
    filename = "invoices-#{month}.zip"

    send_data zip_data, filename: filename, type: "application/zip", disposition: "attachment"
  end

  private

  def set_invoice
    @invoice = current_user.invoices.find(params[:id])
  end

  def create_zip(invoices)
    require "zip"

    buffer = Zip::OutputStream.write_buffer do |zip|
      invoices.each do |invoice|
        next unless invoice.pdf.attached?

        # Create a safe filename with date prefix, vendor name, and invoice id
        date_prefix = invoice.accounting_date.strftime("%Y-%m-%d")
        safe_vendor = invoice.vendor_name.gsub(/[^a-zA-Z0-9\-_]/, "_").truncate(50, omission: "")
        filename = "#{date_prefix}__#{safe_vendor}_#{invoice.id}.pdf"

        zip.put_next_entry(filename)
        zip.write(invoice.pdf.download)
      end
    end

    buffer.string
  end
end
