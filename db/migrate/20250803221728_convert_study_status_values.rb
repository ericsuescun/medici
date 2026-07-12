class ConvertStudyStatusValues < ActiveRecord::Migration[8.0]
  def up
    # Get all studies
    studies = execute("SELECT id FROM studies").to_a

    # No studies to update if the table is empty
    return if studies.empty?

    # Calculate the number of studies to mark as completed (70%)
    completed_count = (studies.size * 0.7).round

    # Get the IDs for completed studies (70%)
    completed_ids = studies.shuffle.take(completed_count).map { |s| s['id'] }

    # Update studies to completed (70%)
    if completed_ids.any?
      execute("UPDATE studies SET study_status = 'completed' WHERE id IN (#{completed_ids.join(',')})")
    end

    # Update remaining studies to recruiting (30%)
    recruiting_ids = studies.map { |s| s['id'] } - completed_ids
    if recruiting_ids.any?
      execute("UPDATE studies SET study_status = 'recruiting' WHERE id IN (#{recruiting_ids.join(',')})")
    end
  end

  def down
    # This migration cannot be reversed as the original values are lost
    raise ActiveRecord::IrreversibleMigration
  end
end
