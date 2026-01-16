class BankConnection < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy

  enum :status, { pending: "pending", linked: "linked", expired: "expired" }
end
