class AddCustomNoteToTransactions < ActiveRecord::Migration[8.0]
  def change
    add_column :transactions, :custom_note, :text
  end
end
