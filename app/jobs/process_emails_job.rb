class ProcessEmailsJob < ApplicationJob
  queue_as :default

  def perform
    require "colorize"

    emails = Email.unprocessed_for_invoices.includes(:attachments)

    if emails.empty?
      puts "No unprocessed emails found.".yellow
      return
    end

    puts "Processing #{emails.count} emails...".cyan
    puts "=" * 60

    emails.find_each do |email|
      process_email(email)
    end

    puts "=" * 60
    puts "Processing complete.".cyan
  end

  private

  def process_email(email)
    pdf_attachments = email.attachments.select(&:file_type_pdf?)
    attachment_names = pdf_attachments.map(&:filename)

    puts "\n#{"Subject:".light_blue} #{email.subject}"
    puts "#{"From:".light_blue} #{email.from_name} <#{email.from_address}>"
    puts "#{"Date:".light_blue} #{email.date&.strftime('%Y-%m-%d %H:%M')}"

    if attachment_names.any?
      puts "#{"PDF Attachments:".light_blue} #{attachment_names.join(', ')}"
    else
      puts "#{"PDF Attachments:".light_blue} (none)"
    end

    is_invoice = DetectInvoiceAgent.new(email, pdf_attachment_names: attachment_names).call

    if is_invoice
      puts "#{"Invoice detected:".light_blue} #{"YES".green.bold}"
    else
      puts "#{"Invoice detected:".light_blue} #{"NO".red}"
    end

    puts "-" * 60
  rescue StandardError => e
    puts "  #{"LLM Error:".red} #{e.message}"
  end
end
