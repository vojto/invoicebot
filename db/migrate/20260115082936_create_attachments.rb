class CreateAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :attachments do |t|
      t.references :email, null: false, foreign_key: true
      t.string :gmail_attachment_id
      t.string :filename
      t.string :mime_type
      t.integer :size

      t.timestamps
    end
  end
end
