class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :google_uid
      t.string :email
      t.string :name
      t.string :picture_url
      t.text :google_access_token
      t.text :google_refresh_token
      t.datetime :google_token_expires_at

      t.timestamps
    end

    add_index :users, :google_uid, unique: true
    add_index :users, :email
  end
end
