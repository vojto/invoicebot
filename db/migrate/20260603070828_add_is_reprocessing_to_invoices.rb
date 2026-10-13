class AddIsReprocessingToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :is_reprocessing, :boolean, default: false, null: false
  end
end
