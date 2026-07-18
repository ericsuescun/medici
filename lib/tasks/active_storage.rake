namespace :active_storage do
  # NOTE: no app constants in desc — rake parses this file before Rails boots.
  desc "Purge blobs unattached longer than PurgeUnattachedBlobsJob::TTL " \
       "(abandoned uploads, failed saves, purges lost to restarts). Run daily via Heroku Scheduler."
  task purge_unattached: :environment do
    purged = PurgeUnattachedBlobsJob.perform_now
    puts "Purged #{purged} unattached blob(s)."
  end

  desc "Report (never delete) storage inconsistencies the purge sweep cannot see: " \
       "service files with no blob row, and blank rich texts still holding embedded images."
  task audit_orphans: :environment do
    service = ActiveStorage::Blob.service

    # List the service BEFORE reading blob rows. Every write path creates the
    # row first and the file second, so a file can only appear in a listing
    # after its row exists — this order can't report an in-flight upload as
    # an orphan (the reverse order would).
    # Dispatch on the class name: only the configured service's class is
    # loaded (S3Service isn't defined in dev, DiskService isn't in prod).
    stored_keys =
      case service.class.name
      when "ActiveStorage::Service::S3Service"
        service.bucket.objects.map(&:key)
      when "ActiveStorage::Service::DiskService"
        # Disk shards files as ab/cd/<key>; the basename is the blob key.
        # Variant files belong to variant blobs, which have their own rows.
        Dir.glob(File.join(service.root, "**", "*"))
          .select { |f| File.file?(f) }.map { |f| File.basename(f) }
      else
        abort "Unsupported service #{service.class} — add a listing branch before auditing."
      end

    known_keys = ActiveStorage::Blob.pluck(:key).to_set

    orphan_files = stored_keys.reject { |key| known_keys.include?(key) }
    puts "#{orphan_files.size} stored file(s) with no blob row:"
    orphan_files.each { |key| puts "  #{key}" }

    # Defense in depth (see SoapNote): a blank rich text holding embeds should
    # be impossible — ""/nil destroys the row (store_if_blank: false) and a
    # Trix-cleared body triggers the embed re-sync — but if either mechanism
    # regresses, blobs stuck here are invisible to the unattached sweep.
    blank_with_embeds = ActionText::RichText.where(body: [ nil, "" ])
      .joins(:embeds_attachments).distinct
    puts "#{blank_with_embeds.count} blank rich text(s) still holding embedded files " \
         "(record ids: #{blank_with_embeds.pluck(:id).join(', ')})"
  end
end
