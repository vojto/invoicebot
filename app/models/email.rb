class Email < ApplicationRecord
  belongs_to :user
  has_many :attachments, dependent: :destroy

  validates :gmail_id, presence: true, uniqueness: { scope: :user_id }
end
