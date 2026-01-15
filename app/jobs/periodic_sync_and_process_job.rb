class PeriodicSyncAndProcessJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting periodic sync and process..."

    User.find_each do |user|
      Rails.logger.info "Syncing emails for #{user.email}..."
      SyncEmailsJob.perform_now(user.id)
    end

    Rails.logger.info "Processing emails..."
    ProcessEmailsJob.perform_now

    Rails.logger.info "Periodic sync and process complete."
  end
end
