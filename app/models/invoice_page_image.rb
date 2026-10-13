class InvoicePageImage < ApplicationRecord
  belongs_to :invoice
  has_one_attached :image
end
