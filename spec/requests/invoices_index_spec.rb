require "rails_helper"

RSpec.describe "Invoices index", type: :request do
  let(:user) { create(:user) }
  let(:connection) { create(:bank_connection, user: user) }
  let(:food) { create(:category, user: user, name: "Food") }
  let(:software) { create(:category, user: user, name: "Software") }

  before { sign_in(user) }

  it "shows monthly invoices and categorized spending ordered by amount" do
    food_invoice = create(:invoice, user: user, category: food, issue_date: Date.new(2026, 7, 5), amount_cents: 1_000)
    software_invoice = create(:invoice, user: user, category: software, issue_date: Date.new(2026, 7, 10), amount_cents: 3_000)
    uncategorized_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 7, 12), amount_cents: 5_000)
    unlinked_invoice = create(:invoice, user: user, category: food, issue_date: Date.new(2026, 7, 13), amount_cents: 6_000)
    credit_note = create(:invoice, user: user, category: food, issue_date: Date.new(2026, 7, 15), amount_cents: 7_000, document_type: :credit_note)
    deleted_invoice = create(:invoice, user: user, category: software, issue_date: Date.new(2026, 7, 18), amount_cents: 8_000, deleted_at: Time.current)
    create(:transaction, bank_connection: connection, invoice: food_invoice)
    create(:transaction, bank_connection: connection, invoice: software_invoice)
    create(:transaction, bank_connection: connection, invoice: uncategorized_invoice)
    create(:transaction, bank_connection: connection, invoice: credit_note, direction: :credit)
    create(:transaction, bank_connection: connection, invoice: deleted_invoice)
    create(:invoice, user: user, issue_date: Date.new(2026, 6, 30), amount_cents: 9_000)

    get "/invoices/month/2026-07", headers: inertia_headers

    expect(response).to have_http_status(:ok)
    page = response.parsed_body
    expect(page["component"]).to eq("invoices/index")
    expect(page.dig("props", "invoice_month")).to eq({ "key" => "2026-07", "label" => "July 2026" })
    expect(page.dig("props", "invoices").pluck("id")).to contain_exactly(
      food_invoice.id,
      software_invoice.id,
      uncategorized_invoice.id,
      unlinked_invoice.id,
      credit_note.id,
      deleted_invoice.id
    )
    expect(page.dig("props", "invoices").find { |invoice| invoice["id"] == unlinked_invoice.id }["bank_transaction"]).to be_nil

    breakdown = page.dig("props", "spending_breakdowns", 0)
    expect(breakdown["total_amount_cents"]).to eq(10_000)
    expect(breakdown["categories"].pluck("name", "amount_cents")).to eq([
      [ "Food", 7_000 ],
      [ "Software", 3_000 ]
    ])
  end

  it "returns not found for an invalid month" do
    get "/invoices/month/not-a-month", headers: inertia_headers

    expect(response).to have_http_status(:not_found)
  end

  it "links the first active accountant access to the selected month" do
    first_access = create(:accountant_access, user: user, name: "First")
    create(:accountant_access, user: user, name: "Second")

    get "/invoices/month/2026-07", headers: inertia_headers

    expect(response.parsed_body.dig("props", "accountant_url")).to eq(
      accountant_root_path(access_token: first_access.public_token, month: "2026-07")
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
