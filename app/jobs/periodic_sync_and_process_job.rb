class PeriodicSyncAndProcessJob < ApplicationJob
  queue_as :default

  def perform(user_id: nil)
    sync_service = EmailSyncService.new
    processing_service = InvoiceProcessingService.new

    if user_id
      user = User.find_by(id: user_id)
      return unless user

      sync_and_process_user(user, sync_service, processing_service)
    else
      sync_and_process_all_users(sync_service, processing_service)
    end
  end

  private

  def sync_and_process_user(user, sync_service, processing_service)
    Rails.logger.info "[SyncJob] Starting sync for #{user.email}..."

    begin
      sync_service.sync_user(user)
      user.update!(last_sync_error: nil)
    rescue => e
      Rails.logger.error "[SyncJob] Sync failed for #{user.email}: #{e.message}"
      user.update!(last_sync_error: e.message)
      return
    end

    Rails.logger.info "[SyncJob] Processing emails for #{user.email}..."
    processing_service.process_user(user)

    user.update!(last_synced_at: Time.current)
    Rails.logger.info "[SyncJob] Sync complete for #{user.email}."
  end

  def sync_and_process_all_users(sync_service, processing_service)
    Rails.logger.info "[SyncJob] Starting periodic sync and process for all users..."

    sync_service.sync_all_users do |user, error|
      if error
        Rails.logger.error "[SyncJob] Sync failed for #{user.email}: #{error.message}"
        user.update!(last_sync_error: error.message)
      else
        user.update!(last_sync_error: nil)
      end
    end

    Rails.logger.info "[SyncJob] Processing emails..."
    processing_service.process_all_users(verbose: true)

    User.update_all(last_synced_at: Time.current)
    Rails.logger.info "[SyncJob] Periodic sync and process complete."
  end
end
