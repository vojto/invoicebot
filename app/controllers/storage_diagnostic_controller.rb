class StorageDiagnosticController < ActionController::Base
  def show
    storage_root = ActiveStorage::Blob.service.root

    results = { storage_root: storage_root, process_uid: Process.uid }

    # Check for root-owned directories
    root_owned = Dir.glob(File.join(storage_root, "*")).select do |dir|
      File.directory?(dir) && File.stat(dir).uid == 0
    end
    results[:root_owned_dirs] = root_owned.map { |d| File.basename(d) }

    # Test writing into each root-owned directory (reproducing the exact error)
    results[:write_tests] = {}
    root_owned.each do |dir|
      dirname = File.basename(dir)
      test_subdir = File.join(dir, "diag_test_#{SecureRandom.hex(2)}")
      begin
        FileUtils.mkdir_p(test_subdir)
        test_file = File.join(test_subdir, "test")
        File.write(test_file, "ok")
        File.delete(test_file)
        Dir.rmdir(test_subdir)
        results[:write_tests][dirname] = "ok"
      rescue => e
        results[:write_tests][dirname] = "#{e.class}: #{e.message}"
      end
    end

    # Also test a random fresh path for comparison
    fresh_key = "#{SecureRandom.hex(2)}/#{SecureRandom.hex(2)}/test_#{Time.now.to_i}"
    fresh_path = File.join(storage_root, fresh_key)
    begin
      FileUtils.mkdir_p(File.dirname(fresh_path))
      File.write(fresh_path, "ok")
      File.delete(fresh_path)
      results[:fresh_write] = "ok"
    rescue => e
      results[:fresh_write] = "#{e.class}: #{e.message}"
    end

    render json: results
  end
end
