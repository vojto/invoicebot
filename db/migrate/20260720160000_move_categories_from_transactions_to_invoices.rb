class MoveCategoriesFromTransactionsToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_reference :invoices, :category, foreign_key: { on_delete: :nullify }

    execute <<~SQL.squish
      UPDATE invoices
      SET category_id = transactions.category_id
      FROM transactions
      WHERE transactions.invoice_id = invoices.id
        AND transactions.category_id IS NOT NULL
    SQL

    remove_reference :transactions, :category, foreign_key: true
  end

  def down
    add_reference :transactions, :category, foreign_key: { on_delete: :nullify }

    execute <<~SQL.squish
      UPDATE transactions
      SET category_id = invoices.category_id
      FROM invoices
      WHERE transactions.invoice_id = invoices.id
        AND invoices.category_id IS NOT NULL
    SQL

    remove_reference :invoices, :category, foreign_key: true
  end
end
