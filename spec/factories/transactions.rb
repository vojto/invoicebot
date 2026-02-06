FactoryBot.define do
  factory :transaction do
    bank_connection
    sequence(:transaction_id) { |n| "tx-#{n}" }
    sequence(:internal_transaction_id) { |n| "int-#{n}" }
    booking_date { Date.current }
    value_date { Date.current }
    amount_cents { 1000 }
    direction { :debit }
    currency { "EUR" }
  end
end
