class PeriodicSyncAndProcessJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting periodic sync and process..."

    User.find_each do |user|
      Rails.logger.info "Syncing emails for #{user.email}..."
      begin
        SyncEmailsJob.perform_now(user.id)
        user.update!(last_sync_error: nil)
      rescue => e
        Rails.logger.error "Sync failed for #{user.email}: #{e.message}"
        user.update!(last_sync_error: e.message)
      end
    end

    Rails.logger.info "Processing emails..."
    ProcessEmailsJob.perform_now

    User.update_all(last_synced_at: Time.current)
    Rails.logger.info "Periodic sync and process complete."
  end
end
