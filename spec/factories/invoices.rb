FactoryBot.define do
  factory :invoice do
    user
    vendor_name { "Test Vendor" }
    amount_cents { 1000 }
    currency { "EUR" }
  end
end
