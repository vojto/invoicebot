require "rails_helper"

RSpec.describe "GET /transactions/:id/invoice_matches", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }
  let(:transaction) { create(:transaction, bank_connection: connection, amount_cents: 5000, currency: "EUR", booking_date: Date.new(2026, 2, 1)) }

  before { sign_in(user) }

  it "returns exact matches when an invoice has the same amount" do
    exact = create(:invoice, user: user, amount_cents: 5000, currency: "EUR", issue_date: Date.new(2026, 2, 1))
    create(:invoice, user: user, amount_cents: 9999, currency: "EUR") # unrelated

    get "/transactions/#{transaction.id}/invoice_matches"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["match_type"]).to eq("exact")
    expect(body["matches"].map { |m| m["id"] }).to eq([exact.id])
  end

  it "returns close matches within 5 EUR when no exact match exists" do
    close = create(:invoice, user: user, amount_cents: 5300, currency: "EUR", issue_date: Date.new(2026, 2, 1))
    create(:invoice, user: user, amount_cents: 9999, currency: "EUR") # too far

    get "/transactions/#{transaction.id}/invoice_matches"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["match_type"]).to eq("close")
    expect(body["matches"].map { |m| m["id"] }).to eq([close.id])
    expect(body["matches"].first["amount_diff_label"]).to be_present
  end

  it "returns empty matches when nothing is close" do
    create(:invoice, user: user, amount_cents: 9999, currency: "EUR")

    get "/transactions/#{transaction.id}/invoice_matches"

    expect(response).to have_http_status(:ok)
    body = response.parsed_body
    expect(body["matches"]).to be_empty
  end

  it "prefers exact matches over close matches" do
    exact = create(:invoice, user: user, amount_cents: 5000, currency: "EUR", issue_date: Date.new(2026, 2, 1))
    create(:invoice, user: user, amount_cents: 5200, currency: "EUR", issue_date: Date.new(2026, 2, 1))

    get "/transactions/#{transaction.id}/invoice_matches"

    body = response.parsed_body
    expect(body["match_type"]).to eq("exact")
    expect(body["matches"].map { |m| m["id"] }).to eq([exact.id])
  end
end
