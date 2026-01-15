namespace :sync do
  desc "Sync emails and process invoices for all users"
  task all: :environment do
    PeriodicSyncAndProcessJob.perform_now
  end

  desc "Sync emails from Gmail for all users"
  task emails: :environment do
    sync_service = EmailSyncService.new
    sync_service.sync_all_users do |user, error|
      if error
        puts "  Error syncing #{user.email}: #{error.message}"
      else
        puts "  Synced #{user.email}"
      end
    end
    puts "All users synced."
  end

  desc "Process unprocessed emails to detect invoices"
  task process: :environment do
    processing_service = InvoiceProcessingService.new
    processing_service.process_all_users(verbose: true)
  end
end
