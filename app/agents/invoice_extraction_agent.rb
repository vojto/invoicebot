# frozen_string_literal: true

class InvoiceExtractionAgent < ApplicationAgent
  instructions <<~PROMPT
    Classify and extract this accounting document using only the document itself.
    Supported types are invoice and credit_note. Use unsupported_document for anything else. Use insufficient_data when the document appears supported but its vendor, total, currency, or accounting date cannot be determined. Set document only when status is extracted.
    A credit_note explicitly credits or reverses an invoice (for example Credit Note, Credit Memo, Dobropis, Gutschrift, or Avoir). Do not infer credit_note merely from a refund mention, a negative line item, a prior payment, or a zero balance.
    For an invoice, total.kind is invoice_total and the amount is the grand total actually charged to the payment method, not the remaining balance. When the document shows totals in multiple currencies, use the amount and currency that the payment section says will be charged. For example, if totals show USD 100.00 and EUR 92.00, and the payment section says "EUR 92.00 will be charged," extract 9200 EUR. For a credit note, total.kind is credit_total and the amount is the credit issued by this document, not the referenced invoice's total. Always return a positive amount in cents.
    Interpret numeric dates using the vendor's country: day/month/year for most countries and month/day/year for the United States. Only return delivery_date when explicitly stated. A header-level service period may use its end date; a period mentioned only inside a line item may not.
    Return vendor_country only when the document identifies it through the vendor address or tax identity. Return vendor_eu_vat_id only for the vendor (not the customer), normalized like SK2120299335 or IE3668997OH using that country's valid VAT ID format, or EU528377759 for the non-Union scheme. Return null when no vendor EU VAT ID is shown.
  PROMPT

  schema do
    title "invoice_extraction"

    string :status, enum: %w[extracted unsupported_document insufficient_data], description: "Extraction outcome"
    any_of :document, description: "Extracted document, or null unless status is extracted" do
      object do
        string :type, enum: %w[invoice credit_note]
        any_of :explicit_label do
          string description: "Document's visible type label, such as Invoice or Credit Note"
          null
        end
        string :vendor_name, description: "Business that issued the document"
        any_of :vendor_country do
          string description: "Vendor country as an uppercase two-letter ISO 3166-1 alpha-2 code"
          null
        end
        any_of :vendor_eu_vat_id do
          string description: "Vendor EU VAT ID in its valid national or EU non-Union scheme format, uppercase without spaces or punctuation"
          null
        end
        any_of :document_number do
          string
          null
        end
        any_of :referenced_invoice_number do
          string
          null
        end
        object :total do
          integer :amount_cents, description: "Positive document total actually charged to the payment method, in cents"
          string :currency, description: "Three-letter ISO currency code for the amount actually charged"
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

  # @param pdf [ActiveStorage::Attached::One, IO, String] The PDF as an attachment, IO, or path
  # @param filename [String, nil] The PDF filename, needed when passing an IO
  def initialize(pdf, filename: nil)
    super()
    @pdf = RubyLLM::Attachment.new(pdf, filename: filename)
  end

  def call
    data = ask_for_data("Extract invoice data from this document.", with: @pdf)
    return { is_invoice: false, extraction_status: data[:status] } unless data[:status] == "extracted"

    document = data[:document]
    raise InvalidResponseError, "Extracted response is incomplete" unless complete?(document)

    extraction_from(document)
  end

  private

  def complete?(document)
    return false if document.blank?

    total = document[:total]
    expected_kind = document[:type] == "credit_note" ? "credit_total" : "invoice_total"

    document[:vendor_name].present? &&
      total[:amount_cents].to_i.positive? &&
      total[:currency].present? &&
      total[:kind] == expected_kind &&
      (document[:issue_date].present? || document[:delivery_date].present?)
  end

  def extraction_from(document)
    {
      is_invoice: true,
      extraction_status: "extracted",
      document_type: document[:type],
      vendor_name: document[:vendor_name],
      vendor_country: normalize_country(document[:vendor_country], document[:vendor_eu_vat_id]),
      vendor_eu_vat_id: EuVatId.normalize(document[:vendor_eu_vat_id]),
      amount_cents: document[:total][:amount_cents],
      currency: document[:total][:currency],
      issue_date: parse_date(document[:issue_date]),
      delivery_date: parse_date(document[:delivery_date]),
      note: note_for(document)
    }
  end

  def normalize_country(country, eu_vat_id)
    normalized = country.to_s.strip.upcase
    normalized.match?(/\A[A-Z]{2}\z/) ? normalized : EuVatId.country_code(eu_vat_id)
  end

  def parse_date(value)
    Date.parse(value) if value.present?
  end

  def note_for(document)
    [
      document[:document_number].presence && "Document number: #{document[:document_number]}",
      document[:referenced_invoice_number].presence && "Referenced invoice: #{document[:referenced_invoice_number]}"
    ].compact.join("; ").presence
  end
end
