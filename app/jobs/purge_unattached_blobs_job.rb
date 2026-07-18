# The safety net for every way a blob can end up in storage with no
# attachment: a Trix image pasted into a note that was never saved, a
# direct-uploaded exam file whose form failed validation or whose session
# expired before submit, and a purge_later that was lost in a dyno restart
# (jobs run in-process — see config/environments/production.rb).
#
# Runs daily in production via Heroku Scheduler (`rails active_storage:purge_unattached`).
class PurgeUnattachedBlobsJob < ApplicationJob
  queue_as :default

  # Long enough that a form left open for a weekend still submits with its
  # uploads intact; direct-uploaded blobs are unattached until the form saves.
  TTL = 3.days

  def perform
    purged = 0
    ActiveStorage::Blob.unattached.where(created_at: ...TTL.ago).find_each do |blob|
      # purge no-ops (rescues the FK violation) if the blob got attached
      # between the query and this call, so a submit racing the sweep is safe.
      blob.purge
      purged += 1 if blob.destroyed?
    end
    Rails.logger.info("PurgeUnattachedBlobsJob: purged #{purged} unattached blob(s)")
    purged
  end
end
