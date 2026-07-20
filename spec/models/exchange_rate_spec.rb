require "rails_helper"

RSpec.describe ExchangeRate, type: :model do
  it "normalizes its currency and month" do
    rate = create(:exchange_rate, currency: "usd", month: Date.new(2026, 6, 20))

    expect(rate.attributes.slice("currency", "month")).to eq(
      "currency" => "USD",
      "month" => Date.new(2026, 6, 1)
    )
  end
end
