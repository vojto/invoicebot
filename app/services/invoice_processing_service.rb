# Service for processing emails and extracting invoices.
#
# Provides methods to:
# - Process all unprocessed emails for all users
# - Process emails for a single user
# - Process a single email
# - Extract invoice from a standalone PDF (without email)
#
class InvoiceProcessingService
  # Process all unprocessed emails for all users.
  #
  # @param verbose [Boolean] Whether to print verbose output
  # @return [void]
  def process_all_users(verbose: false)
    require "colorize" if verbose

    emails = Email.unprocessed_for_invoices.includes(:attachments, :user)

    if emails.empty?
      puts "No unprocessed emails found.".yellow if verbose
      return
    end

    puts "Processing #{emails.count} emails...".cyan if verbose
    puts "=" * 60 if verbose

    emails.find_each do |email|
      process_email(email, verbose: verbose)
    end

    puts "=" * 60 if verbose
    puts "Processing complete.".cyan if verbose
  end

  # Process all unprocessed emails for a single user.
  #
  # @param user [User] The user whose emails to process
  # @param verbose [Boolean] Whether to print verbose output
  # @return [void]
  def process_user(user, verbose: false)
    require "colorize" if verbose

    emails = user.emails.unprocessed_for_invoices.includes(:attachments)

    if emails.empty?
      puts "No unprocessed emails found for #{user.email}.".yellow if verbose
      return
    end

    puts "Processing #{emails.count} emails for #{user.email}...".cyan if verbose
    puts "=" * 60 if verbose

    emails.find_each do |email|
      process_email(email, verbose: verbose)
    end

    puts "=" * 60 if verbose
    puts "Processing complete for #{user.email}.".cyan if verbose
  end

  # Process a single email to detect and extract invoices.
  #
  # @param email [Email] The email to process
  # @param verbose [Boolean] Whether to print verbose output
  # @return [Invoice, nil] The created/updated invoice, or nil if no invoice found
  def process_email(email, verbose: false)
    require "colorize" if verbose

    pdf_attachments = email.attachments.select(&:file_type_pdf?)
    attachment_names = pdf_attachments.map(&:filename)

    result = DetectInvoiceAgent.new(email, pdf_attachment_names: attachment_names).call

    unless result[:invoice_found]
      puts "#{"Skip:".yellow} #{email.subject}" if verbose
      return nil
    end

    if verbose
      puts "\n#{"Subject:".light_blue} #{email.subject}"
      puts "#{"From:".light_blue} #{email.from_name} <#{email.from_address}>"
      puts "#{"Date:".light_blue} #{email.date&.strftime('%Y-%m-%d %H:%M')}"
      puts "#{"Invoice PDF:".light_blue} #{result[:pdf_filename]}" if result[:pdf_filename]
    end

    invoice = extract_and_save_invoice_from_email(email, pdf_attachments, result[:pdf_filename], verbose: verbose)
    puts "-" * 60 if verbose

    invoice
  rescue StandardError => e
    puts "  #{"Error:".red} #{e.message}" if verbose
    puts "-" * 60 if verbose
    Rails.logger.error "[InvoiceProcessingService] Error processing email #{email.id}: #{e.class} - #{e.message}"
    nil
  ensure
    email.update!(is_processed_for_invoices: true)
  end

  # Extract invoice data from a standalone PDF file and create an Invoice record.
  #
  # Use this method when you have a PDF file that wasn't received via email,
  # such as when a user uploads a PDF directly to the application.
  #
  # @param user [User] The user who owns this invoice
  # @param pdf_io [IO, StringIO] The PDF file data
  # @param filename [String] The original filename of the PDF
  # @return [Invoice, nil] The created invoice, or nil if extraction failed
  def extract_invoice_from_pdf(user, pdf_io, filename:)
    Rails.logger.info "[InvoiceProcessingService] Extracting invoice from PDF: #{filename} for user #{user.email}"

    # Read PDF content for both extraction and attachment
    pdf_content = pdf_io.respond_to?(:read) ? pdf_io.read : pdf_io

    # Write PDF to temp file for processing
    temp_file = Tempfile.new([ "uploaded_invoice", ".pdf" ])
    temp_file.binmode
    temp_file.write(pdf_content)
    temp_file.close

    begin
      extraction = InvoiceExtractionAgent.new(pdf_path: temp_file.path, filename: filename).call

      unless extraction[:is_invoice]
        Rails.logger.info "[InvoiceProcessingService] PDF is not a valid invoice: #{filename}"
        return nil
      end

      invoice = user.invoices.create!(
        vendor_name: extraction[:vendor_name],
        amount_cents: extraction[:amount_cents],
        currency: extraction[:currency],
        issue_date: extraction[:issue_date],
        delivery_date: extraction[:delivery_date],
        note: extraction[:note]
      )

      # Attach the PDF directly to the invoice
      invoice.pdf.attach(
        io: StringIO.new(pdf_content),
        filename: filename,
        content_type: "application/pdf"
      )

      Rails.logger.info "[InvoiceProcessingService] Created invoice #{invoice.id} with PDF: #{extraction[:vendor_name]} - #{extraction[:amount_cents]} #{extraction[:currency]}"

      invoice
    ensure
      temp_file.unlink
    end
  end

  private

  def extract_and_save_invoice_from_email(email, pdf_attachments, pdf_filename, verbose: false)
    require "colorize" if verbose

    attachment = find_invoice_attachment(pdf_attachments, pdf_filename)

    unless attachment
      puts "  #{"Warning:".yellow} Could not find PDF attachment '#{pdf_filename}'" if verbose
      return nil
    end

    puts "  #{"Extracting:".light_blue} #{attachment.filename}..." if verbose
    extraction = InvoiceExtractionAgent.new(attachment).call

    unless extraction[:is_invoice]
      puts "  #{"Skipped:".yellow} PDF is not a valid invoice" if verbose
      return nil
    end

    if verbose
      puts "  #{"Vendor:".light_blue} #{extraction[:vendor_name]}"
      puts "  #{"Amount:".light_blue} #{format_amount(extraction[:amount_cents], extraction[:currency])}"
      puts "  #{"Issue date:".light_blue} #{extraction[:issue_date]}"
      puts "  #{"Delivery date:".light_blue} #{extraction[:delivery_date]}"
    end

    invoice = email.invoice || email.build_invoice
    invoice.assign_attributes(
      user: email.user,
      vendor_name: extraction[:vendor_name],
      amount_cents: extraction[:amount_cents],
      currency: extraction[:currency],
      issue_date: extraction[:issue_date],
      delivery_date: extraction[:delivery_date],
      note: extraction[:note]
    )
    invoice.save!

    # Copy the PDF from the email attachment to the invoice
    if attachment.file.attached? && !invoice.pdf.attached?
      invoice.pdf.attach(
        io: StringIO.new(attachment.file.download),
        filename: attachment.filename,
        content_type: attachment.mime_type
      )
    end

    if verbose
      action = invoice.previously_new_record? ? "Created" : "Updated"
      puts "  #{"#{action}:".green} #{extraction[:vendor_name]} - #{format_amount(extraction[:amount_cents], extraction[:currency])}"
    end

    invoice
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
