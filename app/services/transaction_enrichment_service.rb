class TransactionEnrichmentService
  def initialize(bank_connection: nil, user: nil)
    @bank_connection = bank_connection
    @user = user
  end

  def enrich_all
    transactions_to_enrich.find_each do |transaction|
      enrich_transaction(transaction)
    end
  end

  def self.enrich_all
    new.enrich_all
  end

  private

  def transactions_to_enrich
    scope = Transaction.where(is_enriched: false)

    if @bank_connection
      scope = scope.where(bank_connection: @bank_connection)
    elsif @user
      scope = scope.joins(:bank_connection).where(bank_connections: { user_id: @user.id })
    end

    scope
  end

  def enrich_transaction(transaction)
    Rails.logger.info "[TransactionEnrichmentService] Enriching transaction #{transaction.id}"

    result = TransactionEnrichmentAgent.new(transaction).call

    transaction.update!(
      is_enriched: true,
      vendor_name: result[:vendor_name],
      original_currency: result[:original_currency],
      original_amount_cents: result[:original_amount_cents]
    )
  rescue => e
    Rails.logger.error "[TransactionEnrichmentService] Failed to enrich transaction #{transaction.id}: #{e.message}"
  end
end
