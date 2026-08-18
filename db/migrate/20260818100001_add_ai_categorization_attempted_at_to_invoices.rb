class AddAiCategorizationAttemptedAtToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :ai_categorization_attempted_at, :datetime
  end
end
