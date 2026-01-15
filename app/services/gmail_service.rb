class GmailService
  def initialize(user)
    @user = user
  end

  def fetch_emails_with_pdf_attachments(days: 30)
    gmail = build_gmail_client
    query = "newer_than:#{days}d has:attachment filename:pdf"

    messages = []
    page_token = nil

    loop do
      result = gmail.list_user_messages(
        "me",
        q: query,
        page_token: page_token,
        max_results: 100
      )

      break unless result.messages

      messages.concat(result.messages)
      page_token = result.next_page_token
      break unless page_token
    end

    messages
  end

  def fetch_message(message_id)
    gmail = build_gmail_client
    gmail.get_user_message("me", message_id, format: "full")
  end

  def fetch_attachment(message_id, attachment_id)
    gmail = build_gmail_client
    gmail.get_user_message_attachment("me", message_id, attachment_id)
  end

  def sync_emails(days: 30)
    messages = fetch_emails_with_pdf_attachments(days: days)

    messages.each do |message_stub|
      sync_message(message_stub.id)
    end
  end

  private

  def sync_message(gmail_id)
    # Skip if we already have this email
    return if @user.emails.exists?(gmail_id: gmail_id)

    message = fetch_message(gmail_id)
    headers = extract_headers(message)

    email = @user.emails.create!(
      gmail_id: gmail_id,
      thread_id: message.thread_id,
      subject: headers[:subject],
      from_address: headers[:from_address],
      from_name: headers[:from_name],
      to_addresses: headers[:to].to_json,
      date: headers[:date],
      snippet: message.snippet
    )

    sync_attachments(email, message)
  end

  def sync_attachments(email, message)
    return unless message.payload&.parts

    find_pdf_attachments(message.payload.parts).each do |part|
      attachment_id = part.body.attachment_id
      next unless attachment_id

      begin
        attachment_data = fetch_attachment(message.id, attachment_id)
        next unless attachment_data&.data.present?

        attachment = email.attachments.create!(
          gmail_attachment_id: attachment_id,
          filename: part.filename,
          mime_type: part.mime_type,
          size: part.body.size
        )

        # Gmail API may return already decoded data or base64 encoded
        file_data = attachment_data.data
        if file_data.start_with?('%PDF') || !file_data.match?(/\A[A-Za-z0-9_-]+={0,2}\z/)
          # Already decoded binary data
        else
          # Base64 encoded, decode it
          file_data += '=' * (4 - file_data.length % 4) if file_data.length % 4 != 0
          file_data = Base64.urlsafe_decode64(file_data)
        end

        attachment.file.attach(
          io: StringIO.new(file_data),
          filename: part.filename,
          content_type: part.mime_type
        )
      rescue => e
        Rails.logger.error "Failed to sync attachment #{part.filename}: #{e.message}"
        raise e # Re-raise to see the actual error during development
      end
    end
  end

  def find_pdf_attachments(parts, found = [])
    parts.each do |part|
      if part.mime_type == "application/pdf" && part.filename.present?
        found << part
      elsif part.parts
        find_pdf_attachments(part.parts, found)
      end
    end
    found
  end

  def extract_headers(message)
    headers = message.payload.headers.each_with_object({}) do |header, hash|
      hash[header.name.downcase] = header.value
    end

    from_parsed = parse_email_address(headers["from"])

    {
      subject: headers["subject"],
      from_address: from_parsed[:address],
      from_name: from_parsed[:name],
      to: parse_to_addresses(headers["to"]),
      date: headers["date"] ? Time.parse(headers["date"]) : nil
    }
  end

  def parse_email_address(str)
    return { address: nil, name: nil } unless str

    if str =~ /^(.+?)\s*<(.+?)>$/
      { name: $1.gsub(/^"|"$/, ''), address: $2 }
    else
      { name: nil, address: str }
    end
  end

  def parse_to_addresses(str)
    return [] unless str
    str.split(",").map(&:strip)
  end

  def build_gmail_client
    credentials = @user.ensure_fresh_google_credentials!(scopes: GoogleCredentials::SCOPE_GMAIL)

    gmail = Google::Apis::GmailV1::GmailService.new
    gmail.authorization = credentials
    gmail
  end
end
