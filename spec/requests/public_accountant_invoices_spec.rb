require "rails_helper"

RSpec.describe "Public accountant invoices", type: :request do
  let(:user) { create(:user) }
  let(:access) { create(:accountant_access, user: user) }

  it "lists only active invoices belonging to the shared user without signing in" do
    category = create(:category, user: user, name: "Software")
    invoice = create(:invoice, user: user, category: category, issue_date: Date.new(2026, 7, 10))
    connection = create(:bank_connection, user: user, institution_name: "Business account")
    create(
      :transaction,
      bank_connection: connection,
      invoice: invoice,
      booking_date: Date.new(2026, 7, 15),
      amount_cents: 1_234,
      currency: "EUR",
      original_amount_cents: 1_500,
      original_currency: "USD"
    )
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
      "account_name" => "Business account",
      "amount_cents" => 1_234,
      "currency" => "EUR",
      "original_amount_cents" => 1_500,
      "original_currency" => "USD",
      "direction" => "debit"
    })
    expect(response.parsed_body.dig("props", "progress_storage_key")).to match(/\A[0-9a-f]{16}\z/)
    expect(response.headers["Cache-Control"]).to include("no-store")
    expect(response.headers["Referrer-Policy"]).to eq("no-referrer")
    expect(access.reload.last_accessed_at).to be_present
  end

  it "keeps the access token in download and PDF URLs" do
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
    expect(props["download_url"]).to eq(
      accountant_month_download_path(month: "2026-07", access_token: access.public_token)
    )
    expect(props["spreadsheet_url"]).to eq(
      accountant_month_spreadsheet_path(month: "2026-07", access_token: access.public_token)
    )
    expect(props.dig("invoices", 0, "pdf_url")).to eq(
      accountant_invoice_pdf_path(id: invoice.id, access_token: access.public_token)
    )
    expect(props.dig("invoices", 0, "pages_url")).to eq(
      accountant_invoice_pages_path(id: invoice.id, access_token: access.public_token)
    )
    expect(props.dig("invoices", 0)).to include(
      "issue_date" => "2026-07-10",
      "delivery_date" => "2026-07-11",
      "category_name" => nil,
      "vendor_country" => "SK",
      "vendor_eu_vat_id" => "SK2020000000"
    )
    expect(props.dig("invoices", 0)).not_to have_key("note")
    expect(props.dig("table", "columns").pluck("label")).to eq([
      "Vendor",
      "Accounting date",
      "Transaction date",
      "Country / VAT ID",
      "Category",
      "Invoice amount",
      "Bank account",
      "Bank amount",
      "Original amount"
    ])
    expect(
      props.dig("table", "columns").select { |column| column["split_view"] }.pluck("label")
    ).to eq([ "Vendor", "Accounting date", "Country / VAT ID", "Invoice amount" ])
    expect(props.dig("table", "rows", 0, "pdf_url")).to eq(
      accountant_invoice_pdf_url(id: invoice.id, access_token: access.public_token)
    )
    expect(props.dig("table", "rows", 0, "currencies", "invoice_amount")).to eq(invoice.currency)
    expect(props.dig("table", "rows", 0, "values")).to include(
      "vendor_name" => invoice.vendor_name,
      "vendor_country" => "SK",
      "vendor_eu_vat_id" => "SK2020000000"
    )
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

  it "serves token-protected page previews only from the shared user's active invoices" do
    invoice = create(:invoice, user: user)
    page_image = invoice.page_images.create!(page_number: 1)
    page_image.image.attach(io: StringIO.new("JPEG data"), filename: "page-1.jpg", content_type: "image/jpeg")
    other_page = create(:invoice).page_images.create!(page_number: 1)
    other_page.image.attach(io: StringIO.new("Private JPEG"), filename: "private.jpg", content_type: "image/jpeg")

    get accountant_invoice_pages_path(id: invoice.id, access_token: access.public_token)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["pages"]).to eq([ {
      "page_number" => 1,
      "image_url" => accountant_invoice_page_path(
        id: invoice.id,
        page_number: 1,
        access_token: access.public_token
      )
    } ])

    get accountant_invoice_page_path(id: invoice.id, page_number: 1, access_token: access.public_token)
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("image/jpeg")
    expect(response.body).to eq("JPEG data")

    get accountant_invoice_pages_path(id: other_page.invoice_id, access_token: access.public_token)
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

  it "downloads the table columns for the selected month as an Excel workbook" do
    invoice = create(
      :invoice,
      user: user,
      vendor_name: "July Vendor",
      vendor_country: "SK",
      vendor_eu_vat_id: "SK2020000000",
      amount_cents: 12_345,
      currency: "EUR",
      issue_date: Date.new(2026, 7, 10)
    )
    invoice.pdf.attach(io: StringIO.new("July PDF"), filename: "invoice.pdf", content_type: "application/pdf")
    connection = create(:bank_connection, user: user, institution_name: "Business account")
    create(
      :transaction,
      bank_connection: connection,
      invoice: invoice,
      amount_cents: 10_000,
      currency: "USD",
      original_amount_cents: 8_000,
      original_currency: "GBP"
    )

    get accountant_month_spreadsheet_path(
      month: "2026-07",
      access_token: access.public_token
    )

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    expect(response.headers["Content-Disposition"]).to include("invoices-2026-07.xlsx")
    expect(response.body).to start_with("PK")

    Zip::File.open_buffer(response.body) do |zip|
      worksheet = zip.find_entry("xl/worksheets/sheet1.xml").get_input_stream.read.force_encoding(Encoding::UTF_8)
      expect(worksheet).to include("Invoice amount", "Transaction date", "Country / VAT ID", "July Vendor")
      expect(worksheet).to include("SK · SK2020000000")
      expect(worksheet).not_to include(
        "Status", "Issue date", "Delivery date", "Direction", ">PDF<",
        "Invoice currency", "Bank currency", "Original currency"
      )
      styles = zip.find_entry("xl/styles.xml").get_input_stream.read.force_encoding(Encoding::UTF_8)
      expect(styles).to include("mm/dd", "€", "$", "£")
      expect(zip.find_entry("xl/worksheets/_rels/sheet1.xml.rels").get_input_stream.read).to include(
        accountant_invoice_pdf_url(id: invoice.id, access_token: access.public_token)
      )
      expect(zip.find_entry("xl/tables/table1.xml").get_input_stream.read).to include('name="AccountantInvoices"')
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
