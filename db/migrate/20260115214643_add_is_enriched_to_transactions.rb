class AddIsEnrichedToTransactions < ActiveRecord::Migration[8.1]
  def change
    add_column :transactions, :is_enriched, :boolean, default: false, null: false
    add_column :transactions, :vendor_name, :string
    add_column :transactions, :original_currency, :string
    add_column :transactions, :original_amount_cents, :integer
  end
end
