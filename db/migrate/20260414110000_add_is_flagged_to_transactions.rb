class AddIsFlaggedToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :is_flagged, :boolean, default: false, null: false
  end
end
