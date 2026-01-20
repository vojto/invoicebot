class AddInvoiceIdToTransactions < ActiveRecord::Migration[7.1]
  def change
    add_reference :transactions, :invoice, foreign_key: true, index: { unique: true }, null: true
  end
end
