require "rails_helper"

RSpec.describe "Dashboard", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }

  before { sign_in(user) }

  it "orders invoices by accounting date and invoice id" do
    older_invoice = create(:invoice, user: user, issue_date: Date.current.beginning_of_month)
    first_invoice = create(:invoice, user: user, issue_date: Date.current.beginning_of_month + 1)
    second_invoice = create(:invoice, user: user, issue_date: Date.current.beginning_of_month + 1)
    undated_invoice = create(:invoice, user: user)

    get "/dashboard", headers: inertia_headers

    expect(response.parsed_body.dig("props", "invoices").pluck("id")).to eq([
      second_invoice.id,
      first_invoice.id,
      older_invoice.id,
      undated_invoice.id
    ])
  end

  it "shows every invoice from the current month and the two before it" do
    travel_to Date.new(2026, 10, 20) do
      create(:invoice, user: user, issue_date: Date.new(2026, 7, 31))
      august_invoices = create_list(:invoice, 101, user: user, issue_date: Date.new(2026, 8, 1))
      november_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 11, 1))

      get "/dashboard", headers: inertia_headers

      expect(response.parsed_body.dig("props", "invoices").pluck("id")).to match_array([ november_invoice.id, *august_invoices.map(&:id) ])
    end
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
