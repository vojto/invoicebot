FactoryBot.define do
  factory :exchange_rate do
    currency { "USD" }
    month { Date.current.beginning_of_month }
    currency_per_eur { 1.1 }
    fetched_at { Time.current }
  end
end
