# Checks that the vendor page lists only the signed-in user's invoices from that vendor.
require "rails_helper"

RSpec.describe "Invoices vendor", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "lists invoices with the given vendor name" do
    acme_invoice = create(:invoice, user: user, vendor_name: "Acme Ltd.")
    create(:invoice, user: user, vendor_name: "Other Co.")
    create(:invoice, user: create(:user), vendor_name: "Acme Ltd.")

    get "/invoices/vendor", params: { name: "Acme Ltd." }, headers: { "X-Inertia" => "true", "X-Inertia-Version" => ViteRuby.digest }

    page = response.parsed_body
    expect(page["component"]).to eq("invoices/vendor")
    expect(page.dig("props", "vendor_name")).to eq("Acme Ltd.")
    expect(page.dig("props", "invoices").pluck("id")).to eq([ acme_invoice.id ])
  end
end
