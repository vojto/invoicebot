FactoryBot.define do
  factory :bank_connection do
    user
    sequence(:institution_id) { |n| "test-bank-#{n}" }
    sequence(:institution_name) { |n| "Test Bank #{n}" }
    sequence(:requisition_id) { |n| "req-#{n}" }
    sequence(:reference_id) { |n| "ref-#{n}" }
    status { :linked }
  end
end
