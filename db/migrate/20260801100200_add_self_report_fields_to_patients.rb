class AddSelfReportFieldsToPatients < ActiveRecord::Migration[8.0]
  def change
    # "Yo no soy el paciente" on the public form: the person submitting declared
    # they are filling it for somebody else. Recorded because it qualifies the
    # authorization (granted by a proxy, not the titular — a fact the rep and
    # legal review need visible), never inferred.
    add_column :patients, :submitted_by_proxy, :boolean, default: false, null: false
    # Asserted at step 1 ("el/la paciente es mayor de edad"). An assertion by
    # the submitter, not a verification — but Ley 1581 Art. 7 proscribes
    # processing minors' data, so we at least refuse to proceed without it.
    add_column :patients, :adult_confirmed, :boolean, default: false, null: false
    # Patient-picked city (principal cities + "Otra"), for matching to nearby
    # centres. Plaintext like `country`: coarse, low-cardinality, needed for
    # filtering — deterministic encryption of a dozen values protects nothing.
    add_column :patients, :reported_city, :string
  end
end
