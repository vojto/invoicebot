class ChangeTransactionUniqueIndexToComposite < ActiveRecord::Migration[8.1]
  def change
    remove_index :transactions, :internal_transaction_id
    add_index :transactions, [:bank_connection_id, :internal_transaction_id], unique: true
  end
end
