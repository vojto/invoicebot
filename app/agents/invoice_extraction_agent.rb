# frozen_string_literal: true

class InvoiceExtractionAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    boolean :is_invoice, description: "Whether this document is a valid invoice that can be extracted"
    string :vendor_name, nullable: true, description: "The name of the vendor/business issuing the invoice"
    integer :amount_cents, nullable: true, description: "Total amount in cents (e.g., 1999 for $19.99)"
    string :currency, nullable: true, description: "Three-letter currency code (e.g., USD, EUR, CZK)"
    string :issue_date, nullable: true, description: "Invoice issue date in YYYY-MM-DD format"
    string :delivery_date, nullable: true, description: "Delivery/service date in YYYY-MM-DD format"
    string :note, nullable: true, description: "Any additional notes or invoice number"
  end

  MODEL = "gpt-5.2"
  PDF_PAGES_TO_EXTRACT = 2

  SYSTEM_PROMPT = <<~PROMPT
    You are an invoice data extraction assistant. Your task is to analyze documents and extract structured data from invoices.

    First, determine if the document is actually an invoice. Set is_invoice to false if:
    - The document is not an invoice (e.g., a contract, letter, report, manual, etc.)
    - The document is too malformed or unclear to extract meaningful data
    - Essential information (vendor name, amount) cannot be determined

    If is_invoice is true, follow these steps:

    1. First, determine which country the invoice is from based on the vendor address, language, currency, or other contextual clues.

    2. Use the country of origin to interpret date formats correctly:
       - European countries (and most of the world): assume day/month/year format (e.g., 05/01/2026 = January 5th, 2026)
       - United States: assume month/day/year format (e.g., 05/01/2026 = May 1st, 2026)

    3. Extract the following information:
       - vendor_name: The name of the business or company issuing the invoice
       - amount_cents: The total amount to pay, converted to cents (multiply by 100). For example, $19.99 becomes 1999
       - currency: The three-letter currency code (USD, EUR, CZK, GBP, etc.)
       - issue_date: The date the invoice was issued (YYYY-MM-DD format). Most invoices have this, but set to null if not present.
       - delivery_date: The date of delivery or service (YYYY-MM-DD format). This is optional and many invoices don't have it. Only extract if explicitly stated, otherwise set to null.
         If a service/billing period range is explicitly shown (for example, "Zuctovacie obdobie: 1.1.2026 - 31.1.2026"), use the end date of that range as delivery_date.
       - note: Any relevant notes, invoice number, or reference number

    If is_invoice is false, set all other fields to null.

    Be precise with amounts. Always convert to cents by multiplying the decimal amount by 100.
  PROMPT

  # Initialize with either an attachment or a raw PDF path.
  #
  # @param attachment [Attachment, nil] An Attachment model with a PDF file attached
  # @param pdf_path [String, nil] Path to a PDF file on disk
  # @param filename [String, nil] Original filename (used for logging when pdf_path is provided)
  def initialize(attachment = nil, pdf_path: nil, filename: nil)
    @attachment = attachment
    @pdf_path = pdf_path
    @filename = filename

    if @attachment.nil? && @pdf_path.nil?
      raise ArgumentError, "Either attachment or pdf_path must be provided"
    end
  end

  def call
    if @attachment
      raise ArgumentError, "Attachment must have a file attached" unless @attachment.file.attached?
      log_identifier = "attachment #{@attachment.id} (#{@attachment.filename})"
    else
      log_identifier = "file #{@filename || @pdf_path}"
    end

    Rails.logger.info "[InvoiceExtractionAgent] Starting extraction for #{log_identifier}"

    pdf_path = extract_first_pages_pdf
    Rails.logger.info "[InvoiceExtractionAgent] Extracted first #{PDF_PAGES_TO_EXTRACT} pages PDF: #{pdf_path}"

    chat = RubyLLM.chat(model: MODEL)
    chat.with_instructions(SYSTEM_PROMPT)

    start_time = Time.current
    result = chat.with_schema(ResponseSchema).ask("Extract invoice data from this document.", with: pdf_path)
    elapsed_ms = ((Time.current - start_time) * 1000).round

    Rails.logger.info "[InvoiceExtractionAgent] AI response received in #{elapsed_ms}ms"

    content = result.content
    raise "Expected Hash response, got #{content.class}" unless content.is_a?(Hash)

    data = content.with_indifferent_access

    # Parse dates if present
    data[:issue_date] = Date.parse(data[:issue_date]) if data[:issue_date].present?
    data[:delivery_date] = Date.parse(data[:delivery_date]) if data[:delivery_date].present?

    input_tokens = result.input_tokens
    output_tokens = result.output_tokens

    if data[:is_invoice]
      Rails.logger.info "[InvoiceExtractionAgent] Extracted: vendor=#{data[:vendor_name]}, amount=#{data[:amount_cents]} #{data[:currency]}"
    else
      Rails.logger.info "[InvoiceExtractionAgent] Document is not a valid invoice"
    end
    Rails.logger.info "[InvoiceExtractionAgent] Tokens: #{input_tokens} in / #{output_tokens} out"

    {
      is_invoice: data[:is_invoice],
      vendor_name: data[:vendor_name],
      amount_cents: data[:amount_cents],
      currency: data[:currency],
      issue_date: data[:issue_date],
      delivery_date: data[:delivery_date],
      note: data[:note],
      llm_model: MODEL,
      llm_duration_ms: elapsed_ms,
      input_tokens: input_tokens,
      output_tokens: output_tokens
    }
  rescue StandardError => e
    Rails.logger.error "[InvoiceExtractionAgent] Error: #{e.class} - #{e.message}"
    Rails.logger.error "[InvoiceExtractionAgent] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    raise
  ensure
    cleanup_temp_files
  end

  private

  def extract_first_pages_pdf
    source_path = if @attachment
      # Download PDF from attachment to temp file
      @source_pdf_temp_file = Tempfile.new([ "invoice_source", ".pdf" ])
      @source_pdf_temp_file.binmode
      @source_pdf_temp_file.write(@attachment.file.download)
      @source_pdf_temp_file.close
      @source_pdf_temp_file.path
    else
      # Use provided PDF path directly
      @pdf_path
    end

    # Extract first pages using Qpdf wrapper
    @extracted_pdf_temp_file = Tempfile.new([ "invoice_pages", ".pdf" ])
    @extracted_pdf_temp_file.close

    Qpdf.new(source_path).extract_first_pages(
      PDF_PAGES_TO_EXTRACT,
      output_path: @extracted_pdf_temp_file.path
    )

    @extracted_pdf_temp_file.path
  end

  def cleanup_temp_files
    @source_pdf_temp_file&.unlink
    @extracted_pdf_temp_file&.unlink
  end
end
