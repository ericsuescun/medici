class AddObjectChangesToVersions < ActiveRecord::Migration[8.0]
  # PaperTrail populates this automatically when present, letting the change-control
  # view show field-level diffs (what changed), not just who/when.
  #
  # jsonb (not text): PaperTrail then stores/reads the changeset as JSON instead of
  # YAML, avoiding the Rails safe-YAML loader silently dropping `changeset` when it
  # contains ActiveSupport::TimeWithZone (e.g. the always-present updated_at).
  def change
    add_column :versions, :object_changes, :jsonb
  end
end
