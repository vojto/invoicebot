class TransactionSyncJob < ApplicationJob
  queue_as :default

  def perform(bank_connection_id: nil)
    if bank_connection_id
      Rails.logger.info "Starting transaction sync for bank connection #{bank_connection_id}..."
      connection = BankConnection.find(bank_connection_id)
      TransactionSyncService.new(connection).sync
    else
      Rails.logger.info "Starting transaction sync for all bank connections..."
      TransactionSyncService.sync_all
    end
    Rails.logger.info "Transaction sync complete."
  end
end
