require "rails_helper"

RSpec.describe "GET /invoices/:id", type: :request do
  let(:user) { create(:user) }
  let(:email) { create(:email, user: user, subject: "Invoice email") }
  let(:invoice) do
    create(
      :invoice,
      user: user,
      email: email,
      vendor_name: "Hetzner",
      amount_cents: 5365,
      currency: "EUR",
      issue_date: Date.new(2026, 1, 5),
      delivery_date: Date.new(2026, 1, 31),
      note: "Cloud hosting"
    )
  end
  let!(:transaction) do
    create(
      :transaction,
      bank_connection: create(:bank_connection, user: user, institution_name: "Fio banka"),
      invoice: invoice,
      vendor_name: "HETZNER",
      amount_cents: 5365,
      currency: "EUR",
      booking_date: Date.new(2026, 2, 2)
    )
  end

  before { sign_in(user) }

  it "renders the invoice detail page with linked email and transaction data" do
    get "/invoices/#{invoice.id}", headers: inertia_headers

    expect(response).to have_http_status(:ok)

    page = response.parsed_body
    expect(page["component"]).to eq("invoices/show")

    props = page["props"]["invoice"]
    expect(props["vendor_name"]).to eq("Hetzner")
    expect(props["amount_label"]).to eq("53.65 EUR")
    expect(props["issue_date"]).to eq("2026-01-05")
    expect(props["delivery_date"]).to eq("2026-01-31")
    expect(props.dig("email", "subject")).to eq("Invoice email")
    expect(props.dig("bank_transaction", "id")).to eq(transaction.id)
    expect(props.dig("bank_transaction", "amount_label")).to eq("53.65 EUR")
  end

  def inertia_headers
    {
      "X-Inertia" => "true",
      "X-Inertia-Version" => ViteRuby.digest,
      "X-Requested-With" => "XMLHttpRequest",
      "Accept" => "text/html, application/xhtml+xml"
    }
  end
end
