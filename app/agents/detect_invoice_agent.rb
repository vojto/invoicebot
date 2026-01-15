class DetectInvoiceAgent
  MODEL = "gpt-5.2"

  def initialize(email, pdf_attachment_names: [])
    @email = email
    @pdf_attachment_names = pdf_attachment_names
  end

  def call
    chat = RubyLLM.chat(model: MODEL)
    response = chat.ask(prompt)

    result = response.content.strip.downcase
    result.include?("yes")
  end

  private

  def prompt
    <<~PROMPT
      Analyze the following email metadata and determine if this email likely contains an invoice.

      Subject: #{@email.subject}
      From: #{@email.from_name} <#{@email.from_address}>
      Email preview: #{@email.snippet}
      PDF Attachments: #{@pdf_attachment_names.any? ? @pdf_attachment_names.join(', ') : 'None'}

      Consider the following indicators:
      - Subject line mentions invoice, faktura, bill, payment, receipt, order confirmation
      - Sender appears to be a business or service provider
      - PDF attachments with names suggesting invoices (e.g., invoice, faktura, receipt, bill)
      - Email preview mentions amounts, payments, or billing

      Respond with ONLY "YES" or "NO" - nothing else.
      Is this email likely to contain an invoice?
    PROMPT
  end
end
