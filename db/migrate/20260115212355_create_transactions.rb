class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :bank_connection, null: false, foreign_key: true
      t.string :transaction_id
      t.string :internal_transaction_id
      t.date :booking_date
      t.date :value_date
      t.integer :amount_cents
      t.string :currency
      t.string :creditor_name
      t.string :creditor_iban
      t.string :debtor_name
      t.string :debtor_iban
      t.text :description
      t.string :bank_transaction_code

      t.timestamps
    end

    add_index :transactions, :internal_transaction_id, unique: true
    add_index :transactions, :booking_date
  end
end
