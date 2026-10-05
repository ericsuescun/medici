class AddSelfRegisteredToPatients < ActiveRecord::Migration[8.0]
  # "Lead" means a patient who came in through the PUBLIC form and whom nobody
  # has called yet. Until now that was inferred from `firstname` being blank,
  # because the public form could not capture a name — the only way to get a
  # nameless patient was to arrive through it.
  #
  # Step 1 now asks for a name (a rep calling a stranger needs something to say
  # after "buenos días"), so the inference dies: a self-registered patient who
  # types their name would silently stop counting as a lead, and the "Solo
  # leads" toggle a rep works from would under-report by exactly the people who
  # engaged most. Provenance is therefore recorded rather than guessed.
  #
  # The backfill reproduces the old definition exactly for existing rows: every
  # patient with no first name today is one the public form created.
  def up
    add_column :patients, :self_registered, :boolean, default: false, null: false
    add_index :patients, :self_registered

    execute <<~SQL
      UPDATE patients SET self_registered = true WHERE firstname IS NULL OR firstname = ''
    SQL
  end

  def down
    remove_index :patients, :self_registered
    remove_column :patients, :self_registered
  end
end
