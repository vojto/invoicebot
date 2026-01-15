class ProcessEmailsJob < ApplicationJob
  queue_as :default

  def perform
    require "colorize"

    emails = Email.unprocessed_for_invoices.includes(:attachments)

    if emails.empty?
      puts "No unprocessed emails found.".yellow
      return
    end

    puts "Processing #{emails.count} emails...".cyan
    puts "=" * 60

    emails.find_each do |email|
      process_email(email)
    end

    puts "=" * 60
    puts "Processing complete.".cyan
  end

  private

  def process_email(email)
    pdf_attachments = email.attachments.select(&:file_type_pdf?)
    attachment_names = pdf_attachments.map(&:filename)

    result = DetectInvoiceAgent.new(email, pdf_attachment_names: attachment_names).call

    unless result[:invoice_found]
      puts "#{"Skip:".yellow} #{email.subject}"
      return
    end

    puts "\n#{"Subject:".light_blue} #{email.subject}"
    puts "#{"From:".light_blue} #{email.from_name} <#{email.from_address}>"
    puts "#{"Date:".light_blue} #{email.date&.strftime('%Y-%m-%d %H:%M')}"
    puts "#{"Invoice PDF:".light_blue} #{result[:pdf_filename]}" if result[:pdf_filename]

    extract_and_save_invoice(email, pdf_attachments, result[:pdf_filename])

    email.update!(is_processed_for_invoices: true)
    puts "-" * 60
  rescue StandardError => e
    puts "  #{"Error:".red} #{e.message}"
    puts "-" * 60
  end

  def extract_and_save_invoice(email, pdf_attachments, pdf_filename)
    attachment = find_invoice_attachment(pdf_attachments, pdf_filename)

    unless attachment
      puts "  #{"Warning:".yellow} Could not find PDF attachment '#{pdf_filename}'"
      return
    end

    puts "  #{"Extracting:".light_blue} #{attachment.filename}..."
    extraction = InvoiceExtractionAgent.new(attachment).call

    unless extraction[:is_invoice]
      puts "  #{"Skipped:".yellow} PDF is not a valid invoice"
      return
    end

    puts "  #{"Vendor:".light_blue} #{extraction[:vendor_name]}"
    puts "  #{"Amount:".light_blue} #{format_amount(extraction[:amount_cents], extraction[:currency])}"
    puts "  #{"Issue date:".light_blue} #{extraction[:issue_date]}"
    puts "  #{"Delivery date:".light_blue} #{extraction[:delivery_date]}"

    invoice = email.invoice || email.build_invoice
    invoice.assign_attributes(
      vendor_name: extraction[:vendor_name],
      amount_cents: extraction[:amount_cents],
      currency: extraction[:currency],
      issue_date: extraction[:issue_date],
      delivery_date: extraction[:delivery_date],
      note: extraction[:note]
    )
    invoice.save!

    action = invoice.previously_new_record? ? "Created" : "Updated"
    puts "  #{"#{action}:".green} #{extraction[:vendor_name]} - #{format_amount(extraction[:amount_cents], extraction[:currency])}"
  end

  def find_invoice_attachment(pdf_attachments, pdf_filename)
    return pdf_attachments.first if pdf_attachments.one?

    pdf_attachments.find { |a| a.filename == pdf_filename } ||
      pdf_attachments.find { |a| a.filename.downcase.include?(pdf_filename&.downcase || "") } ||
      pdf_attachments.first
  end

  def format_amount(amount_cents, currency)
    amount = amount_cents.to_f / 100
    "#{amount} #{currency}"
  end
end
