class AddVendorIdentityToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :vendor_country, :string
    add_column :invoices, :vendor_eu_vat_id, :string
  end
end
