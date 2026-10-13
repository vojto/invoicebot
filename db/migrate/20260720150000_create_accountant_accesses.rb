class CreateAccountantAccesses < ActiveRecord::Migration[8.1]
  def change
    create_table :accountant_accesses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.text :token_ciphertext, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_accessed_at

      t.timestamps
    end

    add_index :accountant_accesses, :token_digest, unique: true
  end
end
