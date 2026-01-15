class AddDeletedAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :deleted_at, :datetime
  end
end
