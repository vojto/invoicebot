# Service for syncing emails from Gmail for users.
#
# Provides methods to sync emails for all users or a single user.
# Wraps GmailService for the actual Gmail API interactions.
#
class EmailSyncService
  # Sync emails for all users in the system.
  #
  # @param days [Integer] Number of days to look back for emails
  # @yield [user, error] Called after each user sync with the user and any error (nil if successful)
  # @return [void]
  def sync_all_users(days: 30, &block)
    User.find_each do |user|
      begin
        sync_user(user, days: days)
        yield(user, nil) if block_given?
      rescue => e
        yield(user, e) if block_given?
      end
    end
  end

  # Sync emails for a single user.
  #
  # @param user [User] The user to sync emails for
  # @param days [Integer] Number of days to look back for emails
  # @return [void]
  def sync_user(user, days: 30)
    Rails.logger.info "[EmailSyncService] Syncing emails for #{user.email}..."
    service = GmailService.new(user)
    service.sync_emails(days: days)
    Rails.logger.info "[EmailSyncService] Sync complete for #{user.email}"
  end
end
