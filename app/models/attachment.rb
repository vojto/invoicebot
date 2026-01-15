class Attachment < ApplicationRecord
  belongs_to :email
  has_one_attached :file

  validates :gmail_attachment_id, presence: true
  validates :filename, presence: true
end
