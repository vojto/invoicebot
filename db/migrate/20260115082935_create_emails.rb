class CreateEmails < ActiveRecord::Migration[8.1]
  def change
    create_table :emails do |t|
      t.references :user, null: false, foreign_key: true
      t.string :gmail_id
      t.string :thread_id
      t.string :subject
      t.string :from_address
      t.string :from_name
      t.text :to_addresses
      t.datetime :date
      t.text :snippet

      t.timestamps
    end

    add_index :emails, [:user_id, :gmail_id], unique: true
    add_index :emails, :date
  end
end
