class ChangeAmountToAmountCentsInInvoices < ActiveRecord::Migration[8.1]
  def change
    remove_column :invoices, :amount, :decimal
    add_column :invoices, :amount_cents, :integer, null: false, default: 0
  end
end
