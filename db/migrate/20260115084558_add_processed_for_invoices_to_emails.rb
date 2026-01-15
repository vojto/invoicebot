class AddProcessedForInvoicesToEmails < ActiveRecord::Migration[8.1]
  def change
    add_column :emails, :processed_for_invoices, :boolean, default: false, null: false
  end
end
