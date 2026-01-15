class AddAccountingDateToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :accounting_date, :virtual, type: :date,
      as: "COALESCE(delivery_date, issue_date)",
      stored: true
  end
end
