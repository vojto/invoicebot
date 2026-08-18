require "rails_helper"

RSpec.describe "Transactions index", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }

  before { sign_in(user) }

  it "filters transactions to the requested month" do
    category = create(:category, user: user, name: "Software")
    invoice = create(:invoice, user: user, category: category)
    july = create(:transaction, bank_connection: connection, invoice: invoice, booking_date: Date.new(2026, 7, 10))
    july.update!(original_amount_cents: 1_200, original_currency: "USD")
    create(:transaction, bank_connection: connection, booking_date: Date.new(2026, 6, 30))

    get "/transactions/month/2026-07", headers: inertia_headers

    expect(response).to have_http_status(:ok)
    page = response.parsed_body
    expect(page["component"]).to eq("transactions/index")
    expect(page.dig("props", "selected_month")).to eq({ "key" => "2026-07", "label" => "July 2026" })
    serialized_transaction = page.dig("props", "transaction_groups", 0, "transactions", 0)
    expect(serialized_transaction["id"]).to eq(july.id)
    expect(serialized_transaction["is_enriched"]).to be(false)
    expect(serialized_transaction.dig("invoice", "category")).to eq(
      { "id" => category.id, "name" => "Software" }
    )
    expect(serialized_transaction.slice("amount_cents", "currency", "original_amount_cents", "original_currency")).to eq(
      {
        "amount_cents" => 1_000,
        "currency" => "EUR",
        "original_amount_cents" => 1_200,
        "original_currency" => "USD"
      }
    )
    expect(page.dig("props", "categories")).to eq([ { "id" => category.id, "name" => "Software" } ])
  end

  it "returns not found for an invalid month" do
    get "/transactions/month/not-a-month", headers: inertia_headers

    expect(response).to have_http_status(:not_found)
  end

  it "shows expired bank connections with their reconnect action" do
    expired_connection = create(
      :bank_connection,
      user: user,
      status: :expired,
      sync_error: TransactionSyncService::AUTHORIZATION_EXPIRED_MESSAGE
    )

    get "/transactions", headers: inertia_headers

    bank_status = response.parsed_body.dig("props", "bank_sync_statuses").find do |status|
      status["id"] == expired_connection.id
    end

    expect(bank_status).to include(
      "status" => "expired",
      "sync_error" => TransactionSyncService::AUTHORIZATION_EXPIRED_MESSAGE,
      "reconnect_url" => reconnect_bank_path(expired_connection)
    )
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
