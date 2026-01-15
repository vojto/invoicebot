# frozen_string_literal: true

class DetectInvoiceAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    boolean :invoice_found, description: "Whether an invoice was detected in the email"
    string :pdf_filename, nullable: true, description: "The filename of the PDF attachment that is the invoice (null if no invoice found)"
  end

  MODEL = "gpt-5.2"

  SYSTEM_PROMPT = <<~PROMPT
    You are an invoice detection assistant. Your task is to analyze email metadata and determine if the email contains an invoice.

    Consider the following indicators:
    - Subject line mentions invoice, faktura, bill, payment, receipt, order confirmation
    - Sender appears to be a business or service provider
    - PDF attachments with names suggesting invoices (e.g., invoice, faktura, receipt, bill)
    - Email preview mentions amounts, payments, or billing

    If you determine an invoice is present and there are PDF attachments, identify which PDF is most likely the invoice.
    If there are multiple PDFs that could be invoices, pick the one that seems most significant (e.g., the one with "invoice" in the name, or the primary document).
  PROMPT

  def initialize(email, pdf_attachment_names: [])
    @email = email
    @pdf_attachment_names = pdf_attachment_names
  end

  def call
    chat = RubyLLM.chat(model: MODEL)
    chat.with_instructions(SYSTEM_PROMPT)

    result = chat.with_schema(ResponseSchema).ask(prompt)

    content = result.content
    raise "Expected Hash response, got #{content.class}" unless content.is_a?(Hash)

    data = content.with_indifferent_access

    {
      invoice_found: data[:invoice_found],
      pdf_filename: data[:pdf_filename]
    }
  end

  private

  def prompt
    <<~PROMPT
      Analyze this email and determine if it contains an invoice:

      Subject: #{@email.subject}
      From: #{@email.from_name} <#{@email.from_address}>
      Email preview: #{@email.snippet}
      PDF Attachments:
      #{@pdf_attachment_names.any? ? @pdf_attachment_names.map { |name| "- #{name}" }.join("\n      ") : 'None'}

      Does this email contain an invoice? If yes, which PDF attachment is the invoice?
    PROMPT
  end
end
