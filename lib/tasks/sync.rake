namespace :sync do
  desc "Sync emails from Gmail for all users"
  task emails: :environment do
    User.find_each do |user|
      puts "Syncing emails for #{user.email}..."
      SyncEmailsJob.perform_now(user.id)
      puts "  Done."
    end
    puts "All users synced."
  end
end
