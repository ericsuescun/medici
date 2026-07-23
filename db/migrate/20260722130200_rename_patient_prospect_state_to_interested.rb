class RenamePatientProspectStateToInterested < ActiveRecord::Migration[8.0]
  # "prospect" read as sales language for somebody who raised their hand about a
  # clinical trial. The lifecycle is unchanged — only the first state's name:
  # interested -> candidate -> participant.
  def up
    change_column_default :patients, :state, "interested"
    execute "UPDATE patients SET state = 'interested' WHERE state = 'prospect'"
    # PaperTrail keeps the old value inside serialized version objects on
    # purpose: an audit trail records what the state was called at the time.
  end

  def down
    change_column_default :patients, :state, "prospect"
    execute "UPDATE patients SET state = 'prospect' WHERE state = 'interested'"
  end
end
