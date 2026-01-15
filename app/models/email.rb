class Email < ApplicationRecord
  belongs_to :user
  has_many :attachments, dependent: :destroy
  has_one :invoice, dependent: :destroy

  validates :gmail_id, presence: true, uniqueness: { scope: :user_id }

  scope :unprocessed_for_invoices, -> { where(is_processed_for_invoices: false) }
  scope :processed_for_invoices, -> { where(is_processed_for_invoices: true) }
end
