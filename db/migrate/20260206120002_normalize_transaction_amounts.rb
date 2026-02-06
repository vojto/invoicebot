class NormalizeTransactionAmounts < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE transactions
      SET amount_cents = ABS(amount_cents)
      WHERE amount_cents < 0
    SQL

    execute <<~SQL
      UPDATE transactions
      SET original_amount_cents = ABS(original_amount_cents)
      WHERE original_amount_cents IS NOT NULL AND original_amount_cents < 0
    SQL
  end

  def down
    execute <<~SQL
      UPDATE transactions
      SET amount_cents = -amount_cents
      WHERE direction = 'debit' AND amount_cents > 0
    SQL

    execute <<~SQL
      UPDATE transactions
      SET original_amount_cents = -original_amount_cents
      WHERE direction = 'debit' AND original_amount_cents IS NOT NULL AND original_amount_cents > 0
    SQL
  end
end
