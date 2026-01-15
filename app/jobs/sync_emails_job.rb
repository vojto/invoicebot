class SyncEmailsJob < ApplicationJob
  queue_as :default

  def perform(user_id, days: 30)
    user = User.find(user_id)
    service = GmailService.new(user)
    service.sync_emails(days: days)
    user.update!(last_synced_at: Time.current)
  end
end
