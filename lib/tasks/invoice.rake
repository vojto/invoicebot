namespace :invoice do
  desc "Test invoice extraction from a PDF attachment"
  task test_extraction: :environment do
    filename = "invoice-GROQ-TAAS-202601-192347.pdf"

    attachment = Attachment.find_by(filename: filename)

    unless attachment
      puts "Attachment not found: #{filename}"
      exit 1
    end

    puts "Testing invoice extraction for: #{attachment.filename}"
    puts "Email subject: #{attachment.email.subject}"
    puts "From: #{attachment.email.from_name} <#{attachment.email.from_address}>"
    puts ""

    result = InvoiceExtractionAgent.new(attachment.file).call

    puts "Extraction Results:"
    puts "-" * 40
    puts "Vendor Name:   #{result[:vendor_name]}"
    puts "Amount:        #{result[:amount_cents]} cents (#{format_amount(result[:amount_cents], result[:currency])})"
    puts "Currency:      #{result[:currency]}"
    puts "Issue Date:    #{result[:issue_date]}"
    puts "Delivery Date: #{result[:delivery_date]}"
    puts "Note:          #{result[:note]}"
    puts "-" * 40
  end

  def format_amount(amount_cents, currency)
    return "N/A" if amount_cents.nil?
    amount = amount_cents / 100.0
    "#{amount} #{currency}"
  end
end
