class AddInternationalToSponsors < ActiveRecord::Migration[8.0]
  # Flag sponsors that are foreign entities, so patient data flowing to them can
  # be gated on an explicit Ley 1581 Art. 26 cross-border-transfer authorization.
  def change
    add_column :sponsors, :international, :boolean, default: false, null: false
  end
end
