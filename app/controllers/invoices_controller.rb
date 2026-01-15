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

  def download
    month = params[:month]
    return head :bad_request unless month.present? && month.match?(/\A\d{4}-\d{2}\z/)

    year, month_num = month.split("-").map(&:to_i)
    start_date = Date.new(year, month_num, 1)
    end_date = start_date.end_of_month

    invoices = current_user.invoices
      .where(deleted_at: nil)
      .where(accounting_date: start_date..end_date)
      .includes(email: { attachments: { file_attachment: :blob } })

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
        pdf_attachment = invoice.email&.attachments&.find(&:file_type_pdf?)
        next unless pdf_attachment&.file&.attached?

        # Create a safe filename with date prefix, vendor name, and invoice id
        date_prefix = invoice.accounting_date.strftime("%Y-%m-%d")
        safe_vendor = invoice.vendor_name.gsub(/[^a-zA-Z0-9\-_]/, "_").truncate(50, omission: "")
        filename = "#{date_prefix}__#{safe_vendor}_#{invoice.id}.pdf"

        zip.put_next_entry(filename)
        zip.write(pdf_attachment.file.download)
      end
    end

    buffer.string
  end
end
