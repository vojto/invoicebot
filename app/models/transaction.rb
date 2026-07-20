class Transaction < ApplicationRecord
  belongs_to :bank_connection
  belongs_to :invoice, optional: true

  enum :direction, { credit: "credit", debit: "debit" }
  enum :invoice_match_source, { manual: "manual", automatic: "automatic" }, prefix: :invoice_match

  before_validation :sync_invoice_match_source

  private

  def sync_invoice_match_source
    self.invoice_match_source = invoice_id? ? (invoice_match_source || "manual") : nil
  end
end
