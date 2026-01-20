class AddDirectionToTransactions < ActiveRecord::Migration[7.1]
  def up
    add_column :transactions, :direction, :string

    execute <<~SQL
      UPDATE transactions
      SET direction = CASE WHEN amount_cents < 0 THEN 'outflow' ELSE 'inflow' END,
          amount_cents = ABS(amount_cents),
          original_amount_cents = ABS(original_amount_cents)
    SQL

    change_column_null :transactions, :direction, false
    add_index :transactions, :direction
  end

  def down
    remove_index :transactions, :direction
    remove_column :transactions, :direction
  end
end
