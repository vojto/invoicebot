class AddLastSyncErrorToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_sync_error, :text
  end
end
