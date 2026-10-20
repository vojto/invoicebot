# Checks that CloudflareEmailDelivery posts the finished email to Cloudflare's
# send_raw endpoint, and raises when Cloudflare refuses it or bounces it.
require "rails_helper"

RSpec.describe CloudflareEmailDelivery do
  let(:delivery) { CloudflareEmailDelivery.new(account_id: "account-1", api_token: "token-1") }
  let(:mail) { Mail.new(from: "invoicebot@invoices.rinik.net", to: "ada@example.com", subject: "Hello from Invoicebot", body: "Hi") }
  let(:http) { double("http") }

  def stub_cloudflare(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    allow(http).to receive(:request).and_return(response)
  end

  def cloudflare_response(klass, code, body)
    klass.new("1.1", code, "").tap { |response| allow(response).to receive(:body).and_return(body.to_json) }
  end

  def accepted(permanent_bounces: [])
    cloudflare_response(Net::HTTPOK, "200", result: { delivered: [ "ada@example.com" ], queued: [], permanent_bounces: permanent_bounces, message_id: "m-1" })
  end

  it "posts the MIME message with its envelope" do
    stub_cloudflare(accepted)

    delivery.deliver!(mail)

    expect(http).to have_received(:request) do |request|
      expect(request.uri.to_s).to eq("https://api.cloudflare.com/client/v4/accounts/account-1/email/sending/send_raw")
      expect(request["Authorization"]).to eq("Bearer token-1")
      body = JSON.parse(request.body)
      expect(body).to include("from" => "invoicebot@invoices.rinik.net", "recipients" => [ "ada@example.com" ])
      expect(body.fetch("mime_message")).to include("Subject: Hello from Invoicebot")
    end
  end

  it "raises when Cloudflare refuses the request" do
    stub_cloudflare(cloudflare_response(Net::HTTPBadRequest, "400", success: false, errors: [ { code: 10205 } ]))

    expect { delivery.deliver!(mail) }.to raise_error(CloudflareEmailDelivery::Error, /400/)
  end

  it "raises when a recipient bounces permanently" do
    stub_cloudflare(accepted(permanent_bounces: [ "ada@example.com" ]))

    expect { delivery.deliver!(mail) }.to raise_error(CloudflareEmailDelivery::Error, /bounced email to ada@example.com/)
  end
end
