class PeriodicSyncAndProcessJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting periodic sync and process..."

    sync_service = EmailSyncService.new
    processing_service = InvoiceProcessingService.new

    # Sync emails for all users
    sync_service.sync_all_users do |user, error|
      if error
        Rails.logger.error "Sync failed for #{user.email}: #{error.message}"
        user.update!(last_sync_error: error.message)
      else
        user.update!(last_sync_error: nil)
      end
    end

    # Process all unprocessed emails
    Rails.logger.info "Processing emails..."
    processing_service.process_all_users(verbose: true)

    User.update_all(last_synced_at: Time.current)
    Rails.logger.info "Periodic sync and process complete."
  end
end
