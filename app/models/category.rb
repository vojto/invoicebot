class Category < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :nullify

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :user_id, case_sensitive: false }
end
