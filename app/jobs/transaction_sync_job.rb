class TransactionSyncJob < ApplicationJob
  queue_as :default

  def perform(bank_connection_id: nil)
    if bank_connection_id
      Rails.logger.info "Starting transaction sync for bank connection #{bank_connection_id}..."
      connection = BankConnection.find(bank_connection_id)
      TransactionSyncService.new(connection).sync
      Rails.logger.info "Enriching transactions for bank connection #{bank_connection_id}..."
      TransactionEnrichmentService.new(bank_connection: connection).enrich_all
    else
      Rails.logger.info "Starting transaction sync for all bank connections..."
      TransactionSyncService.sync_all
      Rails.logger.info "Enriching all unenriched transactions..."
      TransactionEnrichmentService.enrich_all
    end
    Rails.logger.info "Transaction sync and enrichment complete."
  end
end
