class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :categories,
      "user_id, LOWER(name)",
      unique: true,
      name: "index_categories_on_user_id_and_lower_name"

    add_reference :transactions,
      :category,
      foreign_key: { on_delete: :nullify }
  end
end
