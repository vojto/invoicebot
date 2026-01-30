class AddAccountingDateOverrideToInvoices < ActiveRecord::Migration[8.1]
  def up
    # Add the override column
    add_column :invoices, :accounting_date_override, :date

    # Drop the old generated column and recreate with new formula
    # that prefers the override if present
    remove_column :invoices, :accounting_date
    execute <<-SQL
      ALTER TABLE invoices
      ADD COLUMN accounting_date date
      GENERATED ALWAYS AS (COALESCE(accounting_date_override, delivery_date, issue_date)) STORED
    SQL
  end

  def down
    remove_column :invoices, :accounting_date
    execute <<-SQL
      ALTER TABLE invoices
      ADD COLUMN accounting_date date
      GENERATED ALWAYS AS (COALESCE(delivery_date, issue_date)) STORED
    SQL
    remove_column :invoices, :accounting_date_override
  end
end
