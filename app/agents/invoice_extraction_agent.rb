# frozen_string_literal: true

class InvoiceExtractionAgent < ApplicationAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    string :status, enum: %w[extracted unsupported_document insufficient_data], description: "Extraction outcome"
    any_of :document, description: "Extracted document, or null unless status is extracted" do
      object do
        string :type, enum: %w[invoice credit_note]
        any_of :explicit_label do
          string description: "Document's visible type label, such as Invoice or Credit Note"
          null
        end
        string :vendor_name, description: "Business that issued the document"
        any_of :document_number do
          string
          null
        end
        any_of :referenced_invoice_number do
          string
          null
        end
        object :total do
          integer :amount_cents, description: "Positive document total in cents"
          string :currency, description: "Three-letter ISO currency code"
          string :kind, enum: %w[invoice_total credit_total]
        end
        any_of :issue_date do
          string description: "Issue date in YYYY-MM-DD format"
          null
        end
        any_of :delivery_date do
          string description: "Delivery or service date in YYYY-MM-DD format"
          null
        end
      end
      null
    end
  end

  FIRST_PAGE_COUNT = 1
  FIRST_PAGE_SCOPE = "first_page"
  FULL_PDF_SCOPE = "full_pdf"
  BASE_USER_PROMPT = "Extract invoice data from this document."
  ExtractionAttempt = Struct.new(:data, :elapsed_ms, :input_tokens, :output_tokens, :scope, keyword_init: true)

  SYSTEM_PROMPT = <<~PROMPT
    Classify and extract this accounting document using only the document itself.

    Supported types are invoice and credit_note. Use unsupported_document for anything else. Use insufficient_data when the document appears supported but its vendor, total, currency, or accounting date cannot be determined. Set document only when status is extracted.

    A credit_note explicitly credits or reverses an invoice (for example Credit Note, Credit Memo, Dobropis, Gutschrift, or Avoir). Do not infer credit_note merely from a refund mention, a negative line item, a prior payment, or a zero balance.

    For an invoice, total.kind is invoice_total and the amount is the original grand total charged, not the remaining balance. For a credit note, total.kind is credit_total and the amount is the credit issued by this document, not the referenced invoice's total. Always return a positive amount in cents.

    Interpret numeric dates using the vendor's country: day/month/year for most countries and month/day/year for the United States. Only return delivery_date when explicitly stated. A header-level service period may use its end date; a period mentioned only inside a line item may not.
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
    validate_attachment!
    Rails.logger.info "[InvoiceExtractionAgent] Starting extraction for #{log_identifier}"
    source_path = source_pdf_path
    result_for(extraction_attempts(source_path))
  rescue StandardError => e
    Rails.logger.error "[InvoiceExtractionAgent] Error: #{e.class} - #{e.message}"
    Rails.logger.error "[InvoiceExtractionAgent] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    raise
  ensure
    cleanup_temp_files
  end

  private

  def validate_attachment!
    raise ArgumentError, "Attachment must have a file attached" if @attachment && !@attachment.file.attached?
  end

  def log_identifier
    return "attachment #{@attachment.id} (#{@attachment.filename})" if @attachment

    "file #{@filename || @pdf_path}"
  end

  def source_pdf_path
    if @attachment
      @source_pdf_temp_file = Tempfile.new([ "invoice_source", ".pdf" ])
      @source_pdf_temp_file.binmode
      @source_pdf_temp_file.write(@attachment.file.download)
      @source_pdf_temp_file.close
      @source_pdf_temp_file.path
    else
      # Use provided PDF path directly
      @pdf_path
    end
  end

  def extraction_attempts(source_path)
    first_attempt = extract_from_pdf(first_page_pdf(source_path), scope: FIRST_PAGE_SCOPE)
    return [ first_attempt ] unless needs_full_pdf_retry?(first_attempt.data)

    Rails.logger.info "[InvoiceExtractionAgent] First page did not contain enough invoice data; retrying with full PDF"
    [ first_attempt, extract_from_pdf(source_path, scope: FULL_PDF_SCOPE) ]
  end

  def first_page_pdf(source_path)
    extract_first_pages_pdf(source_path).tap do |path|
      Rails.logger.info "[InvoiceExtractionAgent] Extracted first page PDF: #{path}"
    end
  end

  def extract_first_pages_pdf(source_path)
    @extracted_pdf_temp_file = Tempfile.new([ "invoice_pages", ".pdf" ])
    @extracted_pdf_temp_file.close

    Qpdf.new(source_path).extract_first_pages(
      FIRST_PAGE_COUNT,
      output_path: @extracted_pdf_temp_file.path
    )

    @extracted_pdf_temp_file.path
  end

  def extract_from_pdf(pdf_path, scope:)
    result = ask(user_prompt_for(scope), schema: ResponseSchema, attachment: pdf_path)

    Rails.logger.info "[InvoiceExtractionAgent] AI response received for #{scope} in #{result.elapsed_ms}ms"

    ExtractionAttempt.new(
      data: result.data,
      elapsed_ms: result.elapsed_ms,
      input_tokens: result.input_tokens,
      output_tokens: result.output_tokens,
      scope: scope
    )
  end

  def needs_full_pdf_retry?(data)
    !complete_extraction?(data)
  end

  def result_for(attempts)
    attempt = attempts.last
    data = normalize_data(attempt.data)
    usage = usage_for(attempts)

    log_result(data, attempt, usage)
    response_for(data, attempt, usage)
  end

  def user_prompt_for(scope)
    return BASE_USER_PROMPT unless scope == FIRST_PAGE_SCOPE

    <<~PROMPT
      #{BASE_USER_PROMPT}

      You are only seeing the first page. Return insufficient_data unless the document type, vendor, total, currency, and at least one accounting date are explicit on this page. Never substitute a line item, subtotal, tax row, prior payment, balance, or partial-page amount for the document total.
    PROMPT
  end

  def log_result(data, attempt, usage)
    if data[:is_invoice]
      Rails.logger.info "[InvoiceExtractionAgent] Extracted #{data[:document_type]} from #{attempt.scope}: vendor=#{data[:vendor_name]}, amount=#{data[:amount_cents]} #{data[:currency]}"
    else
      Rails.logger.info "[InvoiceExtractionAgent] Document is not a valid invoice"
    end
    Rails.logger.info "[InvoiceExtractionAgent] Tokens: #{usage[:input_tokens]} in / #{usage[:output_tokens]} out"
  end

  def response_for(data, attempt, usage)
    {
      is_invoice: data[:is_invoice],
      extraction_status: data[:extraction_status],
      document_type: data[:document_type],
      document_label: data[:document_label],
      document_number: data[:document_number],
      referenced_invoice_number: data[:referenced_invoice_number],
      amount_kind: data[:amount_kind],
      vendor_name: data[:vendor_name],
      amount_cents: data[:amount_cents],
      currency: data[:currency],
      issue_date: data[:issue_date],
      delivery_date: data[:delivery_date],
      note: data[:note],
      llm_model: MODEL,
      llm_duration_ms: usage[:elapsed_ms],
      input_tokens: usage[:input_tokens],
      output_tokens: usage[:output_tokens],
      extraction_scope: attempt.scope
    }
  end

  def normalize_data(data)
    return empty_extraction(data[:status]) unless data[:status] == "extracted"
    raise InvalidResponseError, "Extracted response is incomplete" unless complete_extraction?(data)

    document = data[:document]
    total = document[:total]
    {
      is_invoice: true,
      extraction_status: data[:status],
      document_type: document[:type],
      document_label: document[:explicit_label],
      document_number: document[:document_number],
      referenced_invoice_number: document[:referenced_invoice_number],
      vendor_name: document[:vendor_name],
      amount_cents: total[:amount_cents],
      currency: total[:currency],
      amount_kind: total[:kind],
      issue_date: parse_date(document[:issue_date]),
      delivery_date: parse_date(document[:delivery_date]),
      note: extraction_note(document)
    }
  end

  def complete_extraction?(data)
    return false unless data[:status] == "extracted"

    document = data[:document]
    total = document&.dig(:total)
    expected_amount_kind = document&.dig(:type) == "credit_note" ? "credit_total" : "invoice_total"

    document.present? &&
      document[:vendor_name].present? &&
      total.present? &&
      total[:amount_cents].to_i.positive? &&
      total[:currency].present? &&
      total[:kind] == expected_amount_kind &&
      (document[:issue_date].present? || document[:delivery_date].present?)
  end

  def empty_extraction(status)
    {
      is_invoice: false,
      extraction_status: status,
      document_type: nil,
      document_label: nil,
      document_number: nil,
      referenced_invoice_number: nil,
      vendor_name: nil,
      amount_cents: nil,
      currency: nil,
      amount_kind: nil,
      issue_date: nil,
      delivery_date: nil,
      note: nil
    }
  end

  def parse_date(value)
    Date.parse(value) if value.present?
  end

  def extraction_note(document)
    [
      document[:document_number].presence && "Document number: #{document[:document_number]}",
      document[:referenced_invoice_number].presence && "Referenced invoice: #{document[:referenced_invoice_number]}"
    ].compact.join("; ").presence
  end

  def usage_for(attempts)
    {
      elapsed_ms: attempts.sum(&:elapsed_ms),
      input_tokens: attempts.sum { |attempt| attempt.input_tokens.to_i },
      output_tokens: attempts.sum { |attempt| attempt.output_tokens.to_i }
    }
  end

  def cleanup_temp_files
    @source_pdf_temp_file&.unlink
    @extracted_pdf_temp_file&.unlink
  end
end
