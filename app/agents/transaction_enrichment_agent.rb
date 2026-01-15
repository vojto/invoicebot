# frozen_string_literal: true

class TransactionEnrichmentAgent
  class ResponseSchema < ApplicationSchema
    additional_properties false

    string :vendor_name, nullable: true, description: "The name of the vendor/merchant (without address or location details)"
    string :original_currency, nullable: true, description: "Original currency code if different from transaction currency (e.g., USD, EUR). Null if same as transaction currency."
    integer :original_amount_cents, nullable: true, description: "Original amount in cents if different from transaction amount. Null if same as transaction amount."
  end

  MODEL = "gpt-5.2"

  SYSTEM_PROMPT = <<~PROMPT
    You are a transaction data enrichment assistant. Your task is to analyze bank transaction data and extract additional information.

    Given a transaction with its amount, currency, and description/note, extract:

    1. vendor_name: The name of the merchant or vendor. Extract just the business name, not the full address or location.
       - Example: "GROQ INC" (not "GROQ INC, P.O. Box 1778, MOUNTAIN VIEW, 94042, USA")
       - Example: "Apple" (not "Apple Inc., Cupertino, CA")

    2. original_currency: Only fill this if the description indicates the transaction was originally in a DIFFERENT currency than the transaction currency.
       - If the description mentions "částka 110.87 USD" but the transaction is in EUR, set original_currency to "USD"
       - If there's no mention of a different currency, set to null

    3. original_amount_cents: Only fill this if there's an original amount in a different currency.
       - Convert to cents (multiply by 100). For example, 110.87 becomes 11087
       - If there's no original amount mentioned, set to null

    Be careful: only set original_currency and original_amount_cents when the note/description explicitly mentions a different currency than the transaction currency.
  PROMPT

  def initialize(transaction)
    @transaction = transaction
  end

  def call
    Rails.logger.info "[TransactionEnrichmentAgent] Starting enrichment for transaction #{@transaction.id}"

    chat = RubyLLM.chat(model: MODEL)
    chat.with_instructions(SYSTEM_PROMPT)

    prompt = build_prompt

    start_time = Time.current
    result = chat.with_schema(ResponseSchema).ask(prompt)
    elapsed_ms = ((Time.current - start_time) * 1000).round

    Rails.logger.info "[TransactionEnrichmentAgent] AI response received in #{elapsed_ms}ms"

    content = result.content
    raise "Expected Hash response, got #{content.class}" unless content.is_a?(Hash)

    data = content.with_indifferent_access

    Rails.logger.info "[TransactionEnrichmentAgent] Extracted: vendor=#{data[:vendor_name]}, original=#{data[:original_amount_cents]} #{data[:original_currency]}"
    Rails.logger.info "[TransactionEnrichmentAgent] Tokens: #{result.input_tokens} in / #{result.output_tokens} out"

    {
      vendor_name: data[:vendor_name],
      original_currency: data[:original_currency],
      original_amount_cents: data[:original_amount_cents]
    }
  rescue StandardError => e
    Rails.logger.error "[TransactionEnrichmentAgent] Error: #{e.class} - #{e.message}"
    Rails.logger.error "[TransactionEnrichmentAgent] Backtrace: #{e.backtrace&.first(5)&.join("\n")}"
    raise
  end

  private

  def build_prompt
    <<~PROMPT
      Analyze this bank transaction and extract vendor information:

      Transaction amount: #{@transaction.amount_cents / 100.0} #{@transaction.currency}
      Description: #{@transaction.description}
      Creditor: #{@transaction.creditor_name}
      Debtor: #{@transaction.debtor_name}
    PROMPT
  end
end
