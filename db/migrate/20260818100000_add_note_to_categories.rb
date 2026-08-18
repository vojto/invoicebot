class AddNoteToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :note, :text
  end
end
