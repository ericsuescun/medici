# Transactional fixtures roll back blob ROWS, but files written to the test
# Disk service (tmp/storage, see config/storage.yml) survive — without this,
# every suite run leaves the files behind and tmp/storage grows forever.
RSpec.configure do |config|
  config.after(:suite) do
    # Glob (not rm_rf of the directory) so the tracked tmp/storage/.keep survives.
    FileUtils.rm_rf(Dir.glob(Rails.root.join("tmp/storage/*")))
  end
end
