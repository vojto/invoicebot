module GmailDataDecoder
  # Gmail API may return attachment data either as raw binary or base64url encoded.
  # This method normalizes the data to raw binary.
  def self.decode(data)
    return data if already_decoded?(data)

    # Base64 encoded, decode it
    # Pad the string if needed (base64url may omit padding)
    data += '=' * (4 - data.length % 4) if data.length % 4 != 0
    Base64.urlsafe_decode64(data)
  end

  def self.already_decoded?(data)
    # Check if it starts with PDF magic bytes
    return true if data.start_with?('%PDF')

    # Check if it contains non-base64 characters (binary data)
    !data.match?(/\A[A-Za-z0-9_-]+={0,2}\z/)
  end
end
