class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :email, null: false, foreign_key: true
      t.string :vendor_name
      t.text :note
      t.date :issue_date
      t.date :delivery_date
      t.decimal :amount, precision: 10, scale: 2
      t.string :currency

      t.timestamps
    end
  end
end
