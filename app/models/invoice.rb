# Represents an invoice extracted from an email attachment.
#
# Each invoice is linked to exactly one email (the source email containing the PDF).
# We store only the total amount charged - no subtotals or tax breakdowns, as we're
# only interested in matching the final sum against bank transactions.
#
# Fields not stored (by design):
# - invoice_number: Not needed for our matching purposes
# - due_date: Not relevant for historical matching
# - tax_amount/subtotal: Only total amount matters for bank matching
# - vendor_tax_id/address: Vendor name is sufficient for identification
# - payment_reference/variable_symbol: Not needed for our use case
#
class Invoice < ApplicationRecord
  belongs_to :email

  validates :vendor_name, presence: true
  validates :amount_cents, presence: true
  validates :currency, presence: true
end
