require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "orders invoices by accounting date and invoice id" do
    older_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 1, 1))
    first_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 1, 2))
    second_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 1, 2))
    undated_invoice = create(:invoice, user: user)

    get "/dashboard", headers: inertia_headers

    expect(response.parsed_body.dig("props", "invoices").pluck("id")).to eq([
      second_invoice.id,
      first_invoice.id,
      older_invoice.id,
      undated_invoice.id
    ])
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
