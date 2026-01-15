namespace :data do
  desc "Wipe all data except users (emails, invoices, attachments)"
  task wipe: :environment do
    puts "This will delete all emails, invoices, and attachments."
    puts "Users will be preserved."
    puts ""
    puts "Current counts:"
    puts "  Emails: #{Email.count}"
    puts "  Invoices: #{Invoice.count}"
    puts "  Attachments: #{Attachment.count}"
    puts ""

    print "Are you sure? (yes/no): "
    confirmation = $stdin.gets.chomp

    unless confirmation == "yes"
      puts "Aborted."
      exit
    end

    puts ""
    puts "Deleting invoices..."
    Invoice.delete_all

    puts "Deleting attachments..."
    Attachment.delete_all

    puts "Purging Active Storage blobs..."
    ActiveStorage::Blob.unattached.find_each(&:purge)

    puts "Deleting emails..."
    Email.delete_all

    puts ""
    puts "Done. All data wiped except users."
  end
end
