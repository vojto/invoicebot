namespace :emails do
  desc "Sync emails from Gmail for all users"
  task sync_all: :environment do
    User.find_each do |user|
      puts "Syncing emails for #{user.email}..."
      SyncEmailsJob.perform_later(user.id)
    end
    puts "Done. Jobs enqueued for #{User.count} users."
  end

  desc "Sync emails from Gmail for a specific user (by email)"
  task :sync, [:email] => :environment do |_t, args|
    user = User.find_by!(email: args[:email])
    puts "Syncing emails for #{user.email}..."
    SyncEmailsJob.perform_now(user.id)
    puts "Done."
  end
end
