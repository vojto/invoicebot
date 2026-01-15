class ChangeFileTypeToStringInAttachments < ActiveRecord::Migration[8.1]
  def up
    # Convert integer values to strings before changing column type
    execute <<-SQL
      UPDATE attachments SET file_type = CASE file_type
        WHEN 0 THEN 'pdf'
        WHEN 1 THEN 'image'
        ELSE NULL
      END
    SQL

    change_column :attachments, :file_type, :string
  end

  def down
    execute <<-SQL
      UPDATE attachments SET file_type = CASE file_type
        WHEN 'pdf' THEN '0'
        WHEN 'image' THEN '1'
        ELSE NULL
      END
    SQL

    change_column :attachments, :file_type, :integer, using: 'file_type::integer'
  end
end
