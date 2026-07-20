class AddInvoiceMatchSourceToTransactions < ActiveRecord::Migration[8.1]
  def up
    add_column :transactions, :invoice_match_source, :string

    execute <<~SQL.squish
      UPDATE transactions
      SET invoice_match_source = 'manual'
      WHERE invoice_id IS NOT NULL
    SQL

    add_check_constraint :transactions,
      "invoice_match_source IN ('manual', 'automatic') OR invoice_match_source IS NULL",
      name: "transactions_invoice_match_source"
  end

  def down
    remove_check_constraint :transactions, name: "transactions_invoice_match_source"
    remove_column :transactions, :invoice_match_source
  end
end
