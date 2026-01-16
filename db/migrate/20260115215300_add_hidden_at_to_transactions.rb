class AddHiddenAtToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :hidden_at, :datetime
  end
end
