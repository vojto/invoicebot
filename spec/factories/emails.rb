FactoryBot.define do
  factory :email do
    user
    sequence(:gmail_id) { |n| "gmail-#{n}" }
    subject { "Test Email" }
    from_address { "sender@example.com" }
    date { Time.current }
  end
end
