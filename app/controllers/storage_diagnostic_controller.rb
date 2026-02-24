class StorageDiagnosticController < ActionController::Base
  def show
    storage_root = ActiveStorage::Blob.service.root

    # Try creating a nested directory like Active Storage would
    test_key = "#{SecureRandom.hex(2)}/#{SecureRandom.hex(2)}/test_#{Time.now.to_i}"
    test_path = File.join(storage_root, test_key)

    results = { storage_root: storage_root, test_key: test_key, test_path: test_path }

    begin
      FileUtils.mkdir_p(File.dirname(test_path))
      File.write(test_path, "diagnostic test")
      results[:write] = "ok"
      results[:file_owner] = File.stat(test_path).uid
      results[:dir_owner] = File.stat(File.dirname(test_path)).uid
      results[:process_uid] = Process.uid

      # Clean up
      File.delete(test_path)
      results[:cleanup] = "ok"
    rescue => e
      results[:error] = "#{e.class}: #{e.message}"
    end

    # Check for root-owned directories
    root_owned = Dir.glob(File.join(storage_root, "*")).select do |dir|
      File.directory?(dir) && File.stat(dir).uid == 0
    end
    results[:root_owned_dirs] = root_owned.map { |d| File.basename(d) }

    render json: results
  end
end
