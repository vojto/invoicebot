# frozen_string_literal: true

class TransactionEnrichmentAgent < ApplicationAgent
  instructions <<~PROMPT
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

  schema do
    title "transaction_enrichment"

    any_of :vendor_name, description: "The name of the vendor/merchant (without address or location details)" do
      string
      null
    end
    any_of :original_currency, description: "Original currency code if different from transaction currency (e.g., USD, EUR). Null if same as transaction currency." do
      string
      null
    end
    any_of :original_amount_cents, description: "Original amount in cents if different from transaction amount. Null if same as transaction amount." do
      integer
      null
    end
  end

  def initialize(transaction)
    super()
    @transaction = transaction
  end

  def call
    ask_for_data(prompt)
  end

  private

  def prompt
    <<~PROMPT
      Analyze this bank transaction and extract vendor information:
      Transaction amount: #{@transaction.amount_cents / 100.0} #{@transaction.currency}
      Description: #{@transaction.description}
      Creditor: #{@transaction.creditor_name}
      Debtor: #{@transaction.debtor_name}
    PROMPT
  end
end
