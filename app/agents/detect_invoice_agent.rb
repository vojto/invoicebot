# frozen_string_literal: true

class DetectInvoiceAgent < ApplicationAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    boolean :invoice_found, description: "Whether an invoice or credit note was detected in the email"
    string :pdf_filename, nullable: true, description: "The filename of the PDF attachment that is the invoice or credit note"
  end

  SYSTEM_PROMPT = <<~PROMPT
    Determine whether this email contains an invoice or credit note, and select its PDF attachment.

    Consider the following indicators:
    - Subject or filename mentions invoice, faktura, bill, receipt, credit note, credit memo, dobropis, gutschrift, avoir, or refund
    - Sender appears to be a business or service provider
    - Email preview mentions amounts, payments, or billing

    Return false when there is no plausible accounting-document PDF. If several PDFs qualify, select the primary invoice or credit note rather than supporting material.
  PROMPT

  def initialize(email, pdf_attachment_names: [])
    @email = email
    @pdf_attachment_names = pdf_attachment_names
  end

  def call
    data = ask(prompt, schema: ResponseSchema).data

    {
      invoice_found: data[:invoice_found],
      pdf_filename: data[:pdf_filename]
    }
  end

  private

  def prompt
    <<~PROMPT
      Analyze this email:

      Subject: #{@email.subject}
      From: #{@email.from_name} <#{@email.from_address}>
      Email preview: #{@email.snippet}
      PDF Attachments:
      #{@pdf_attachment_names.any? ? @pdf_attachment_names.map { |name| "- #{name}" }.join("\n      ") : 'None'}

      Does it contain an invoice or credit note? If yes, which PDF is it?
    PROMPT
  end
end
