class NormalizeTransactionDirection < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE transactions SET direction = 'credit' WHERE direction = 'inflow';
      UPDATE transactions SET direction = 'debit' WHERE direction = 'outflow';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE transactions SET direction = 'inflow' WHERE direction = 'credit';
      UPDATE transactions SET direction = 'outflow' WHERE direction = 'debit';
    SQL
  end
end
