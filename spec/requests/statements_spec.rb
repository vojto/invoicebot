require "rails_helper"

RSpec.describe "GET /statements/:month", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user, institution_name: "Fio banka") }

  before { sign_in(user) }

  it "returns monthly statement sections with in-month and supplemental rows" do
    january_tx_missing_invoice = create(
      :transaction,
      bank_connection: connection,
      booking_date: Date.new(2026, 1, 15),
      amount_cents: 9000,
      currency: "EUR",
      vendor_name: "Orange"
    )

    january_tx_hidden = create(
      :transaction,
      bank_connection: connection,
      booking_date: Date.new(2026, 1, 18),
      amount_cents: 1200,
      currency: "EUR",
      vendor_name: "Cloudflare",
      hidden_at: Time.current
    )

    january_invoice_with_feb_tx = create(
      :invoice,
      user: user,
      issue_date: Date.new(2026, 1, 20),
      vendor_name: "OpenAI",
      amount_cents: 40027,
      currency: "USD",
      note: "API"
    )

    february_tx_linked_to_january_invoice = create(
      :transaction,
      bank_connection: connection,
      booking_date: Date.new(2026, 2, 2),
      amount_cents: 34676,
      currency: "EUR",
      vendor_name: "OPENAI",
      invoice: january_invoice_with_feb_tx
    )

    january_invoice_without_transaction = create(
      :invoice,
      user: user,
      issue_date: Date.new(2026, 1, 22),
      vendor_name: "Hetzner",
      amount_cents: 5365,
      currency: "EUR"
    )

    february_invoice = create(
      :invoice,
      user: user,
      issue_date: Date.new(2026, 2, 5),
      vendor_name: "Groq",
      amount_cents: 12296,
      currency: "USD"
    )

    create(
      :transaction,
      bank_connection: connection,
      booking_date: Date.new(2026, 2, 6),
      amount_cents: 10752,
      currency: "EUR",
      vendor_name: "GROQ INC",
      invoice: february_invoice
    )

    get "/statements/2026-01", headers: inertia_headers

    expect(response).to have_http_status(:ok)
    page = response.parsed_body
    expect(page["component"]).to eq("statements/show")

    props = page["props"]
    primary_rows = props.dig("primary_section", "rows")
    primary_ids = primary_rows.map { |row| row["transaction_id"] }

    expect(primary_ids).to include(january_tx_missing_invoice.id, january_tx_hidden.id)
    expect(primary_ids).not_to include(february_tx_linked_to_january_invoice.id)
    expect(primary_ids).to eq([january_tx_missing_invoice.id, january_tx_hidden.id])

    missing_invoice_row = primary_rows.find { |row| row["transaction_id"] == january_tx_missing_invoice.id }
    expect(missing_invoice_row["invoice_missing"]).to eq(true)

    hidden_row = primary_rows.find { |row| row["transaction_id"] == january_tx_hidden.id }
    expect(hidden_row["hidden"]).to eq(true)

    supplemental_rows = props.dig("supplemental_sections", 0, "rows")
    supplemental_ids = supplemental_rows.map { |row| row["transaction_id"] }
    expect(props.dig("supplemental_sections", 0, "month_key")).to eq("2026-02")
    expect(supplemental_ids).to eq([february_tx_linked_to_january_invoice.id])
    expect(supplemental_rows.first["vendor_label"]).to eq("OPENAI")

    invoice_only_ids = props["invoice_only_rows"].map { |row| row["invoice_id"] }
    expect(invoice_only_ids).to include(january_invoice_without_transaction.id)
    expect(invoice_only_ids).not_to include(january_invoice_with_feb_tx.id)
  end

  it "returns not found for invalid month key" do
    get "/statements/not-a-month", headers: inertia_headers

    expect(response).to have_http_status(:not_found)
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
