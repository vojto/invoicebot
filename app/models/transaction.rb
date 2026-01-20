class Transaction < ApplicationRecord
  belongs_to :bank_connection
  belongs_to :invoice, optional: true

  enum :direction, {
    inflow: "inflow",
    outflow: "outflow"
  }

  validates :direction, presence: true
end
