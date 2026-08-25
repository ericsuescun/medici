# Removes the SOAP notes feature (model, controller, views and routes went with
# this migration).
#
# The table is the easy half. SoapNote had FOUR `has_rich_text` sections, and
# Action Text rows are POLYMORPHIC — `action_text_rich_texts` rows keyed
# `record_type = 'SoapNote'` are not touched by dropping `soap_notes`, and
# neither are the `active_storage_attachments` rows holding each body's embedded
# images. Left behind they are unreachable rows pointing at a table that no
# longer exists, and the images would stay attached forever, invisible to the
# daily unattached-blob sweep. So both are cleared here, oldest-dependency-first.
#
# The blobs themselves are deliberately NOT destroyed inline: detaching them
# makes them unattached, which is exactly what `PurgeUnattachedBlobsJob` /
# `rails active_storage:purge_unattached` exists to reclaim (after its 3-day
# TTL). That keeps deletion of remote S3 objects out of a migration.
#
# PaperTrail: SoapNote was versioned. Those `versions` rows are deleted here
# too — confirmed with the product owner that no production SOAP notes ever
# existed, so the history describes nothing that happened and keeping rows
# whose `item_type` names a dropped model is just dead weight. (Had there been
# real notes, the call would go the other way: an audit trail records what
# happened at the time, and retiring a feature is not a reason to erase it.)
class DropSoapNotes < ActiveRecord::Migration[8.0]
  def up
    rich_text_ids = select_values(
      "SELECT id FROM action_text_rich_texts WHERE record_type = 'SoapNote'"
    )

    if rich_text_ids.any?
      say "detaching embeds from #{rich_text_ids.size} SoapNote rich-text rows"
      execute(<<~SQL.squish)
        DELETE FROM active_storage_attachments
        WHERE record_type = 'ActionText::RichText'
          AND record_id IN (#{rich_text_ids.join(',')})
      SQL
      execute("DELETE FROM action_text_rich_texts WHERE record_type = 'SoapNote'")
    end

    versions = select_value("SELECT COUNT(*) FROM versions WHERE item_type = 'SoapNote'").to_i
    if versions.positive?
      say "deleting #{versions} PaperTrail versions for SoapNote"
      execute("DELETE FROM versions WHERE item_type = 'SoapNote'")
    end

    drop_table :soap_notes
  end

  # Structure only — the notes themselves are gone for good.
  def down
    create_table :soap_notes do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :author, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.date :encounter_date, null: false

      t.timestamps
    end
  end
end
