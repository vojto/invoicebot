class RenameProcessedForInvoicesToIsProcessedForInvoices < ActiveRecord::Migration[8.1]
  def change
    rename_column :emails, :processed_for_invoices, :is_processed_for_invoices
  end
end
