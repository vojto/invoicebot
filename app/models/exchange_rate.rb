class ExchangeRate < ApplicationRecord
  validates :currency, presence: true, format: { with: /\A[A-Z]{3}\z/ }
  validates :month, :currency_per_eur, :fetched_at, presence: true
  validates :currency_per_eur, numericality: { greater_than: 0 }
  validates :currency, uniqueness: { scope: :month }

  before_validation :normalize_values

  private

  def normalize_values
    self.currency = currency.to_s.upcase.presence
    self.month = month&.beginning_of_month
  end
end
