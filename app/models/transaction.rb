class Transaction < ApplicationRecord
  belongs_to :bank_connection
  belongs_to :invoice, optional: true
  belongs_to :category, optional: true

  enum :direction, { credit: "credit", debit: "debit" }
  enum :invoice_match_source, { manual: "manual", automatic: "automatic" }, prefix: :invoice_match

  before_validation :sync_invoice_match_source
  validate :category_belongs_to_user

  private

  def sync_invoice_match_source
    self.invoice_match_source = invoice_id? ? (invoice_match_source || "manual") : nil
  end

  def category_belongs_to_user
    return unless category && bank_connection
    return if category.user_id == bank_connection.user_id

    errors.add(:category, "must belong to the transaction owner")
  end
end
