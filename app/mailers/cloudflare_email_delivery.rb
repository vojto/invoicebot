require "net/http"

# Action Mailer delivery method that sends through Cloudflare's Email Sending
# API, registered as :cloudflare in config/initializers/cloudflare_email.rb.
# Hands Cloudflare the finished MIME message Rails built, so headers and
# multipart bodies go out as they are. Raises when Cloudflare refuses the
# request or permanently bounces a recipient.
# Docs: https://developers.cloudflare.com/api/resources/email_sending/methods/send_raw/
class CloudflareEmailDelivery
  API_URL = "https://api.cloudflare.com/client/v4/accounts/%s/email/sending/send_raw"

  class Error < StandardError; end

  # Mail reads the settings back through this.
  attr_reader :settings

  def initialize(settings)
    @settings = settings
  end

  def deliver!(mail)
    result = post(from: mail.smtp_envelope_from, recipients: mail.smtp_envelope_to, mime_message: mail.encoded)
    if result.fetch("permanent_bounces").any?
      raise Error, "Cloudflare permanently bounced email to #{result.fetch("permanent_bounces").join(", ")}"
    end
  end

  private
    def post(body)
      request = Net::HTTP::Post.new(URI(format(API_URL, settings.fetch(:account_id))))
      request["Authorization"] = "Bearer #{settings.fetch(:api_token)}"
      request["Content-Type"] = "application/json"
      request.body = body.to_json
      response = Net::HTTP.start(request.uri.host, request.uri.port, use_ssl: true) { |http| http.request(request) }
      raise Error, "Cloudflare email failed (#{response.code}): #{response.body}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).fetch("result")
    end
end
