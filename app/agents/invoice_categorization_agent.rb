# frozen_string_literal: true

class InvoiceCategorizationAgent < ApplicationAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    integer :category_id, nullable: true, description: "Id of the best-fitting category, or null when none clearly fits"
  end

  SYSTEM_PROMPT = <<~PROMPT
    You file invoices into a user's own bookkeeping categories.
    You get one invoice and the full list of categories. Each category has an id, a name, and sometimes a note describing what belongs in it.
    Pick the single category the invoice clearly belongs to and return its id. Be conservative: a plausible guess is worse than no answer here. Return null whenever the invoice does not clearly match a category, several categories fit equally well, or you have too little information about the invoice.
    Only return an id from the list.
  PROMPT

  def initialize(invoice)
    @invoice = invoice
  end

  def call
    categories = @invoice.user.categories.order(:name).to_a
    return nil if categories.empty?

    chosen_id = ask(prompt_for(categories), schema: ResponseSchema).data[:category_id]
    categories.find { |category| category.id == chosen_id }
  end

  private

  def prompt_for(categories)
    <<~PROMPT
      Invoice:
      #{invoice_description}

      Categories:
      #{categories.map { |category| category_description(category) }.join("\n")}

      Which category does this invoice belong to?
    PROMPT
  end

  def invoice_description
    [
      "Vendor: #{@invoice.vendor_name}",
      "Amount: #{formatted_amount}",
      "Document type: #{@invoice.document_type}",
      "Note: #{@invoice.note.presence || 'None'}"
    ].join("\n")
  end

  def formatted_amount
    return "Unknown" if @invoice.amount_cents.blank?

    "#{@invoice.amount_cents / 100.0} #{@invoice.currency}"
  end

  def category_description(category)
    "- id #{category.id}: #{category.name} — #{category.note.presence || 'no note'}"
  end
end
