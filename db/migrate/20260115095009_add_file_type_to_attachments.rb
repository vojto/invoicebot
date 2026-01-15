class AddFileTypeToAttachments < ActiveRecord::Migration[8.1]
  def change
    add_column :attachments, :file_type, :integer
  end
end
