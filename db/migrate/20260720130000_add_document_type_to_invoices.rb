class AddDocumentTypeToInvoices < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :document_type, :string, default: "invoice", null: false
    add_check_constraint :invoices,
      "document_type IN ('invoice', 'credit_note')",
      name: "invoices_document_type"
  end

  def down
    remove_check_constraint :invoices, name: "invoices_document_type"
    remove_column :invoices, :document_type
  end
end
