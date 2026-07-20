class CreateExchangeRates < ActiveRecord::Migration[8.1]
  def change
    create_table :exchange_rates do |t|
      t.string :currency, null: false
      t.date :month, null: false
      t.decimal :currency_per_eur, precision: 20, scale: 10, null: false
      t.datetime :fetched_at, null: false

      t.timestamps
    end

    add_index :exchange_rates, [ :currency, :month ], unique: true
  end
end
