require "set"

class InvoiceSpendingBreakdown
  REPORTING_CURRENCY = "EUR"

  def initialize(invoices, exchange_rates: EcbExchangeRateService.new)
    @invoices = invoices
    @exchange_rates = exchange_rates
  end

  def call
    category_totals = Hash.new(0)
    unconverted_currencies = Set.new

    @invoices.each do |invoice|
      next if invoice.soft_deleted? || !invoice.document_type_invoice?
      next unless invoice.amount_cents.present? && invoice.currency.present?

      category_totals[invoice.category] += converted_amount(invoice)
    rescue EcbExchangeRateService::RateUnavailable
      unconverted_currencies << invoice.currency
    end

    total_amount_cents = category_totals.values.sum
    {
      currency: REPORTING_CURRENCY,
      total_amount_cents: total_amount_cents,
      total_amount_label: format_amount(total_amount_cents),
      unconverted_currencies: unconverted_currencies.to_a.sort,
      categories: serialize_categories(category_totals)
    }
  end

  private

  def converted_amount(invoice)
    @exchange_rates.convert_to_eur(
      invoice.amount_cents,
      currency: invoice.currency,
      month: invoice.accounting_date
    )
  end

  def serialize_categories(category_totals)
    category_totals
      .sort_by { |_, amount_cents| -amount_cents }
      .map do |category, amount_cents|
        {
          id: category&.id,
          name: category&.name || "Uncategorized",
          uncategorized: category.nil?,
          amount_cents: amount_cents,
          amount_label: format_amount(amount_cents)
        }
      end
  end

  def format_amount(amount_cents)
    ActiveSupport::NumberHelper.number_to_currency(
      amount_cents.to_f / 100,
      unit: REPORTING_CURRENCY,
      format: "%n %u"
    )
  end
end
