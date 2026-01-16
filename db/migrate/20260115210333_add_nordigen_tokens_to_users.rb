class AddNordigenTokensToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nordigen_access_token, :text
    add_column :users, :nordigen_refresh_token, :text
    add_column :users, :nordigen_token_expires_at, :datetime
  end
end
