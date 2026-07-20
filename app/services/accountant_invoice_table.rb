class AccountantInvoiceTable
  Column = Data.define(:key, :label, :kind, :width, :split_view) do
    def self.build(key:, label:, kind:, width:, split_view: false)
      new(key: key, label: label, kind: kind, width: width, split_view: split_view)
    end

    def as_json(*)
      {
        key: key,
        label: label,
        kind: kind,
        width: width,
        split_view: split_view,
        align: case kind
               when :amount then :end
               when :flag then :center
               else :start
               end
      }
    end
  end

  COLUMNS = [
    Column.build(key: :accounting_date, label: "Accounting date", kind: :date, width: 16, split_view: true),
    Column.build(key: :delivery_date, label: "Delivery date", kind: :date, width: 14),
    Column.build(key: :transaction_date, label: "Transaction date", kind: :date, width: 16),
    Column.build(key: :vendor_name, label: "Vendor", kind: :text, width: 28, split_view: true),
    Column.build(key: :vendor_country, label: "Country", kind: :flag, width: 10, split_view: true),
    Column.build(key: :vendor_eu_vat_id, label: "VAT ID", kind: :text, width: 18, split_view: true),
    Column.build(key: :category_name, label: "Category", kind: :text, width: 18),
    Column.build(key: :invoice_amount, label: "Invoice amount", kind: :amount, width: 18, split_view: true),
    Column.build(key: :bank_account, label: "Bank account", kind: :text, width: 22),
    Column.build(key: :bank_amount, label: "Bank amount", kind: :amount, width: 18),
    Column.build(key: :original_amount, label: "Original amount", kind: :amount, width: 18)
  ].freeze

  attr_reader :invoices

  def initialize(invoices, pdf_url:)
    @invoices = invoices
    @pdf_url = pdf_url
  end

  def columns
    COLUMNS
  end

  def rows
    invoices.map do |invoice|
      transaction = invoice.bank_transaction

      {
        invoice_id: invoice.id,
        pdf_url: @pdf_url.call(invoice),
        currencies: {
          invoice_amount: invoice.currency,
          bank_amount: transaction&.currency,
          original_amount: transaction&.original_currency
        },
        values: columns.to_h { |column| [ column.key, value_for(invoice, column.key) ] }
      }
    end
  end

  private

  def value_for(invoice, key)
    transaction = invoice.bank_transaction

    case key
    when :vendor_name then invoice.vendor_name
    when :vendor_country then invoice.vendor_country
    when :vendor_eu_vat_id then invoice.vendor_eu_vat_id
    when :category_name then invoice.category&.name
    when :accounting_date then invoice.accounting_date
    when :delivery_date then invoice.delivery_date
    when :invoice_amount then amount(invoice.amount_cents)
    when :transaction_date then (transaction&.booking_date || transaction&.value_date)
    when :bank_account then transaction&.bank_connection&.institution_name.presence
    when :bank_amount then amount(transaction&.amount_cents)
    when :original_amount then amount(transaction&.original_amount_cents)
    end
  end

  def amount(amount_cents)
    amount_cents&.fdiv(100)
  end
end
