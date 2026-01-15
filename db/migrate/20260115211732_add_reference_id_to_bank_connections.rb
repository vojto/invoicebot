class AddReferenceIdToBankConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_connections, :reference_id, :string
    add_index :bank_connections, :reference_id, unique: true
  end
end
