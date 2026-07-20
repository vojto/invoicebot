require "rails_helper"

RSpec.describe "Public accountant invoices", type: :request do
  let(:user) { create(:user) }
  let(:access) { create(:accountant_access, user: user) }

  it "lists only active invoices belonging to the shared user without signing in" do
    category = create(:category, user: user, name: "Software")
    invoice = create(:invoice, user: user, category: category, issue_date: Date.new(2026, 7, 10))
    connection = create(:bank_connection, user: user, institution_name: "Business account")
    create(:transaction, bank_connection: connection, invoice: invoice, booking_date: Date.new(2026, 7, 15))
    create(:invoice, user: user, issue_date: Date.new(2026, 7, 11), deleted_at: Time.current)
    create(:invoice, issue_date: Date.new(2026, 7, 12))
    create(:invoice, user: user, issue_date: Date.new(2026, 6, 30))

    get accountant_month_path(
      month: "2026-07",
      access_token: access.public_token
    ), headers: inertia_headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["component"]).to eq("accountant/invoices/show")
    expect(response.parsed_body.dig("props", "invoices").pluck("id")).to eq([ invoice.id ])
    expect(response.parsed_body.dig("props", "invoices", 0, "category_name")).to eq("Software")
    expect(response.parsed_body.dig("props", "invoices", 0, "transaction")).to eq({
      "date" => "2026-07-15",
      "account_name" => "Business account"
    })
    expect(response.parsed_body.dig("props", "progress_storage_key")).to match(/\A[0-9a-f]{16}\z/)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(access.reload.last_accessed_at).to be_present
  end

  it "keeps the access token in month navigation and PDF URLs" do
    invoice = create(
      :invoice,
      user: user,
      issue_date: Date.new(2026, 7, 10),
      delivery_date: Date.new(2026, 7, 11),
      vendor_country: "SK",
      vendor_eu_vat_id: "SK2020000000"
    )
    invoice.pdf.attach(io: StringIO.new("%PDF-1.4 test"), filename: "invoice.pdf", content_type: "application/pdf")

    get accountant_month_path(
      month: "2026-07",
      access_token: access.public_token
    ), headers: inertia_headers

    props = response.parsed_body["props"]
    expect(props["previous_month_url"]).to eq(
      accountant_month_path(month: "2026-06", access_token: access.public_token)
    )
    expect(props["next_month_url"]).to eq(
      accountant_month_path(month: "2026-08", access_token: access.public_token)
    )
    expect(props["download_url"]).to eq(
      accountant_month_download_path(month: "2026-07", access_token: access.public_token)
    )
    expect(props.dig("invoices", 0, "pdf_url")).to eq(
      accountant_invoice_pdf_path(id: invoice.id, access_token: access.public_token)
    )
    expect(props.dig("invoices", 0)).to include(
      "issue_date" => "2026-07-10",
      "delivery_date" => "2026-07-11",
      "category_name" => nil,
      "vendor_country" => "SK",
      "vendor_eu_vat_id" => "SK2020000000"
    )
    expect(props.dig("invoices", 0)).not_to have_key("note")
  end

  it "orders invoices from oldest to newest" do
    newer_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 7, 20))
    older_invoice = create(:invoice, user: user, issue_date: Date.new(2026, 7, 2))

    get accountant_month_path(
      month: "2026-07",
      access_token: access.public_token
    ), headers: inertia_headers

    expect(response.parsed_body.dig("props", "invoices").pluck("id")).to eq([
      older_invoice.id,
      newer_invoice.id
    ])
  end

  it "redirects generated links to a self-contained month URL" do
    open_access(access)
  end

  it "serves PDFs only from the shared user's active invoices" do
    invoice = create(:invoice, user: user)
    invoice.pdf.attach(io: StringIO.new("%PDF-1.4 test"), filename: "invoice.pdf", content_type: "application/pdf")
    other_invoice = create(:invoice)
    other_invoice.pdf.attach(io: StringIO.new("%PDF-1.4 private"), filename: "private.pdf", content_type: "application/pdf")

    get accountant_invoice_pdf_path(id: invoice.id, access_token: access.public_token)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/pdf")

    get accountant_invoice_pdf_path(id: other_invoice.id, access_token: access.public_token)
    expect(response).to have_http_status(:not_found)
  end

  it "downloads the shared user's active invoices for the selected month as a ZIP" do
    invoice = create(:invoice, user: user, vendor_name: "July Vendor", issue_date: Date.new(2026, 7, 10))
    invoice.pdf.attach(io: StringIO.new("July PDF"), filename: "invoice.pdf", content_type: "application/pdf")
    create(:invoice, user: user, issue_date: Date.new(2026, 6, 30))
    create(:invoice, issue_date: Date.new(2026, 7, 10))

    get accountant_month_download_path(month: "2026-07", access_token: access.public_token)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/zip")
    expect(response.headers["Content-Disposition"]).to include("invoices-2026-07.zip")

    Zip::File.open_buffer(response.body) do |zip|
      expect(zip.entries.map(&:name)).to eq([ "2026-07-10__July_Vendor_#{invoice.id}.pdf" ])
      expect(zip.entries.first.get_input_stream.read).to eq("July PDF")
    end
  end

  it "returns not found for invalid, revoked, and malformed links" do
    get accountant_month_path(month: "2026-07")
    expect(response).to have_http_status(:not_found)

    get accountant_root_path(access_token: "invalid", month: "2026-07")
    expect(response).to have_http_status(:not_found)

    access.revoke!
    get accountant_root_path(access_token: access.public_token, month: "2026-07")
    expect(response).to have_http_status(:not_found)

    active_access = create(:accountant_access, user: user)
    get accountant_root_path(access_token: active_access.public_token, month: "bad-month")
    expect(response).to have_http_status(:not_found)
  end

  it "invalidates shared URLs when their token is regenerated" do
    original_token = access.public_token
    access.rotate_token!

    get accountant_month_path(month: "2026-07", access_token: original_token)

    expect(response).to have_http_status(:not_found)
  end

  def open_access(accountant_access, month = "2026-07")
    get accountant_root_path(access_token: accountant_access.public_token, month: month)
    expect(response).to redirect_to(
      accountant_month_path(month: month, access_token: accountant_access.public_token)
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
