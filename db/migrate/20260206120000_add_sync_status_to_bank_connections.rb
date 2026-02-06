class AddSyncStatusToBankConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :bank_connections, :sync_running, :boolean, default: false, null: false
    add_column :bank_connections, :sync_completed_at, :datetime
    add_column :bank_connections, :sync_error, :text
  end
end
