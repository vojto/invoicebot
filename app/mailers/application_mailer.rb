# Base class for Invoicebot's emails, sent through Cloudflare in production
# (CloudflareEmailDelivery).
class ApplicationMailer < ActionMailer::Base
  default from: "Invoicebot <invoicebot@invoices.rinik.net>"
  layout "mailer"
end
