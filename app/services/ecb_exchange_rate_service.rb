require "csv"
require "net/http"

class EcbExchangeRateService
  class RateUnavailable < StandardError; end

  BASE_URL = "https://data-api.ecb.europa.eu/service/data/EXR"
  CURRENT_RATE_TTL = 12.hours

  def initialize(http_get: nil)
    @http_get = http_get || method(:download)
    @rates = {}
    @failures = {}
  end

  def convert_to_eur(amount_cents, currency:, month:)
    return amount_cents if currency.to_s.upcase == "EUR"

    (BigDecimal(amount_cents.to_s) / currency_per_eur(currency: currency, month: month)).round
  end

  def currency_per_eur(currency:, month:)
    currency = normalize_currency(currency)
    month = month.to_date.beginning_of_month
    key = [ currency, month ]
    return @rates[key] if @rates.key?(key)
    raise @failures[key] if @failures.key?(key)

    stored_rate = ExchangeRate.find_by(currency: currency, month: month)
    return @rates[key] = stored_rate.currency_per_eur if fresh?(stored_rate, month)

    rate = fetch_rate(currency, month)
    ExchangeRate.upsert(
      {
        currency: currency,
        month: month,
        currency_per_eur: rate,
        fetched_at: Time.current,
        created_at: Time.current,
        updated_at: Time.current
      },
      unique_by: [ :currency, :month ],
      update_only: [ :currency_per_eur, :fetched_at ]
    )
    @rates[key] = rate
  rescue RateUnavailable => error
    return @rates[key] = stored_rate.currency_per_eur if stored_rate

    @failures[key] = error
    raise
  end

  private

  def normalize_currency(currency)
    normalized = currency.to_s.upcase
    return normalized if normalized.match?(/\A[A-Z]{3}\z/)

    raise RateUnavailable, "Invalid currency: #{currency.inspect}"
  end

  def fresh?(rate, month)
    return false unless rate
    return rate.fetched_at.to_date > month.end_of_month if month < Date.current.beginning_of_month

    rate.fetched_at >= CURRENT_RATE_TTL.ago
  end

  def fetch_rate(currency, month)
    monthly_values = observations("M", currency, month.strftime("%Y-%m"), month.strftime("%Y-%m"))
    return monthly_values.first if monthly_values.any?

    end_date = [ month.end_of_month, Date.current ].min
    daily_values = observations("D", currency, month.iso8601, end_date.iso8601)
    raise RateUnavailable, "No ECB rate for #{currency} in #{month.strftime('%Y-%m')}" if daily_values.empty?

    daily_values.sum / daily_values.length
  end

  def observations(frequency, currency, start_period, end_period)
    uri = URI("#{BASE_URL}/#{frequency}.#{currency}.EUR.SP00.A")
    uri.query = URI.encode_www_form(startPeriod: start_period, endPeriod: end_period, detail: "dataonly")
    body = @http_get.call(uri)

    CSV.parse(body, headers: true).filter_map do |row|
      BigDecimal(row["OBS_VALUE"]) if row["OBS_VALUE"].present?
    end
  rescue CSV::MalformedCSVError => error
    raise RateUnavailable, "Invalid ECB response: #{error.message}"
  end

  def download(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      response = http.get(uri.request_uri, "Accept" => "text/csv")
      raise RateUnavailable, "ECB request failed with #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  rescue SocketError, Timeout::Error, SystemCallError => error
    raise RateUnavailable, "ECB request failed: #{error.message}"
  end
end
