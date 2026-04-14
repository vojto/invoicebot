class ChangeInvoiceAmountCentsNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :invoices, :amount_cents, true
    change_column_default :invoices, :amount_cents, from: 0, to: nil
  end
end
