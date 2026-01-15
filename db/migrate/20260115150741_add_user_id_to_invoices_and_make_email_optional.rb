class AddUserIdToInvoicesAndMakeEmailOptional < ActiveRecord::Migration[8.1]
  def change
    # Add user_id column (nullable initially for backfill)
    add_reference :invoices, :user, null: true, foreign_key: true

    # Backfill user_id from email.user_id for existing invoices
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE invoices
          SET user_id = emails.user_id
          FROM emails
          WHERE invoices.email_id = emails.id
        SQL
      end
    end

    # Make user_id required after backfill
    change_column_null :invoices, :user_id, false

    # Make email_id optional (for standalone PDF uploads)
    change_column_null :invoices, :email_id, true
  end
end
