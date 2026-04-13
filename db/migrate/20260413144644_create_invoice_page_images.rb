class CreateInvoicePageImages < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_page_images do |t|
      t.references :invoice, null: false, foreign_key: true
      t.integer :page_number, null: false

      t.timestamps

      t.index [:invoice_id, :page_number], unique: true
    end
  end
end
