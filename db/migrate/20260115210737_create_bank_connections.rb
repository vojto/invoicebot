class CreateBankConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :bank_connections do |t|
      t.references :user, null: false, foreign_key: true
      t.string :institution_id
      t.string :institution_name
      t.string :requisition_id
      t.string :status, default: "pending"

      t.timestamps
    end

    add_index :bank_connections, :requisition_id, unique: true
  end
end
