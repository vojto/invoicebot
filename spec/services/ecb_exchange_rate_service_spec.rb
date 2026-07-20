require "rails_helper"

RSpec.describe EcbExchangeRateService do
  include ActiveSupport::Testing::TimeHelpers

  it "fetches, stores, and applies a completed monthly ECB rate" do
    csv = <<~CSV
      KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE
      EXR.M.USD.EUR.SP00.A,M,USD,EUR,SP00,A,2026-06,1.1518
    CSV
    requested_uri = nil
    service = described_class.new(http_get: ->(uri) { requested_uri = uri; csv })

    converted_amount = service.convert_to_eur(11_518, currency: "USD", month: Date.new(2026, 6, 15))

    expect(converted_amount).to eq(10_000)
    expect(requested_uri.to_s).to include("/M.USD.EUR.SP00.A", "startPeriod=2026-06")
    expect(ExchangeRate.find_by!(currency: "USD", month: Date.new(2026, 6, 1)).currency_per_eur).to eq(1.1518)
  end

  it "averages daily observations when the monthly rate is not published yet" do
    responses = [
      "KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE\n",
      <<~CSV
        KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE
        EXR.D.USD.EUR.SP00.A,D,USD,EUR,SP00,A,2026-07-01,1.1
        EXR.D.USD.EUR.SP00.A,D,USD,EUR,SP00,A,2026-07-02,1.2
      CSV
    ]
    requested_uris = []
    service = described_class.new(http_get: ->(uri) { requested_uris << uri; responses.shift })

    travel_to Time.zone.local(2026, 7, 20, 12) do
      expect(service.currency_per_eur(currency: "USD", month: Date.new(2026, 7, 1))).to eq(1.15)
    end

    expect(requested_uris.last.to_s).to include("/D.USD.EUR.SP00.A", "endPeriod=2026-07-20")
  end

  it "raises when the ECB has no observations for a currency" do
    empty_csv = "KEY,FREQ,CURRENCY,CURRENCY_DENOM,EXR_TYPE,EXR_SUFFIX,TIME_PERIOD,OBS_VALUE\n"
    service = described_class.new(http_get: ->(_uri) { empty_csv })

    expect {
      service.currency_per_eur(currency: "XYZ", month: Date.new(2026, 6, 1))
    }.to raise_error(described_class::RateUnavailable)
  end
end
