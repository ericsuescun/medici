class CreateConsents < ActiveRecord::Migration[8.0]
  # Ley 1581 de 2012 habeas-data authorization capture (Art. 6, 9): explicit,
  # prior, informed authorization to process sensitive health data. One immutable
  # record per authorization event, attributable to the user who granted it.
  def change
    create_table :consents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :document_type, null: false   # e.g. "ley_1581_habeas_data"
      t.string :document_version, null: false # which version of the text was accepted
      t.string :purpose, null: false          # e.g. "sensitive_health_data_processing"
      t.datetime :granted_at, null: false
      t.string :ip_address                    # audit context of the acceptance

      t.timestamps
    end

    add_index :consents, [ :user_id, :document_type ]
  end
end
