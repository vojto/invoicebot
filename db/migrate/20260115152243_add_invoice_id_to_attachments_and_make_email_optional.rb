class AddInvoiceIdToAttachmentsAndMakeEmailOptional < ActiveRecord::Migration[8.1]
  def change
    # Add invoice_id column (nullable - for directly uploaded attachments)
    add_reference :attachments, :invoice, null: true, foreign_key: true

    # Make email_id optional (for standalone uploaded attachments)
    change_column_null :attachments, :email_id, true
  end
end
