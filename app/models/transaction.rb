class Transaction < ApplicationRecord
  belongs_to :bank_connection
  belongs_to :invoice, optional: true

  enum :direction, { credit: "credit", debit: "debit" }
end
