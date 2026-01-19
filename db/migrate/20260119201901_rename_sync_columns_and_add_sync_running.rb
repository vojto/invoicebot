class RenameSyncColumnsAndAddSyncRunning < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :last_synced_at, :sync_completed_at
    rename_column :users, :last_sync_error, :sync_error
    add_column :users, :sync_running, :boolean, default: false, null: false
  end
end
