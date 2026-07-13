# Example eligibility profile modeled from a real severe seborrheic-dermatitis
# protocol, to demonstrate the CriteriaProfile / CriteriaVariable engine and the
# evaluator. Idempotent. Dev/demo only — not wired into db/seeds.rb by default
# (it creates an admin-owned example profile). Run manually:
#
#   require_relative "db/seeds/example_seborrheic_dermatitis_profile"
#   profile = ExampleSeborrheicDermatitisProfile.seed!
#   ExampleSeborrheicDermatitisProfile.demo!(profile)   # sample eligible patient
module ExampleSeborrheicDermatitisProfile
  PROFILE_NAME = "Dermatitis seborreica grave — criterios de inclusión/exclusión".freeze

  # [name, value_type, comparison_type, reference_value_1, reference_value_2]
  INCLUSION = [
    [ "Edad (años)", "quantitative", "between_range", 18, 40 ],
    [ "Puntuación de severidad", "quantitative", "more_than_or_equal", 20, nil ],
    [ "Afectación BSA (%)", "quantitative", "more_than_or_equal", 10, nil ],
    [ "Duración de la enfermedad (meses)", "quantitative", "more_than_or_equal", 3, nil ],
    [ "Candidato a terapia sistémica", "boolean", "true", nil, nil ]
  ].freeze

  EXCLUSION = [
    [ "Infección sistémica activa (últimas 2 semanas)", "boolean", "true", nil, nil ],
    [ "Planes de vacunas vivas", "boolean", "true", nil, nil ],
    [ "Condición que impide adherencia (juicio del investigador)", "boolean", "true", nil, nil ],
    [ "Hipersensibilidad o alergia al medicamento", "boolean", "true", nil, nil ],
    [ "Abuso de alcohol o drogas (últimas 24 semanas)", "boolean", "true", nil, nil ],
    [ "No dispuesto a limitar exposición UV", "boolean", "true", nil, nil ]
  ].freeze

  def self.seed!
    owner = User.admins.first || FactoryBot.create(:user, :admin)

    profile = CriteriaProfile.find_or_create_by!(name: PROFILE_NAME, user: owner) do |p|
      p.description = "Ejemplo a partir de un protocolo de dermatitis seborreica grave."
      p.study = Study.first
    end

    order = 0
    (INCLUSION.map { |r| [ "inclusion", r ] } + EXCLUSION.map { |r| [ "exclusion", r ] }).each do |variable_type, (name, value_type, comparison_type, ref1, ref2)|
      order += 1
      variable = profile.criteria_variables.find_or_initialize_by(name: name)
      variable.assign_attributes(
        variable_type: variable_type, value_type: value_type, comparison_type: comparison_type,
        reference_value_1: ref1, reference_value_2: ref2, criteria_order: order
      )
      variable.save!
    end

    profile
  end

  # Build a sample patient whose answers satisfy the profile and return the
  # EligibilityResult (demonstrates the evaluator end to end).
  def self.demo!(profile)
    patient = Patient.create!(dob: Date.new(1990, 1, 1), sex: "female")
    answers = {
      "Edad (años)" => 34, "Puntuación de severidad" => 22, "Afectación BSA (%)" => 15,
      "Duración de la enfermedad (meses)" => 8, "Candidato a terapia sistémica" => true,
      "Infección sistémica activa (últimas 2 semanas)" => false, "Planes de vacunas vivas" => false,
      "Condición que impide adherencia (juicio del investigador)" => false,
      "Hipersensibilidad o alergia al medicamento" => false,
      "Abuso de alcohol o drogas (últimas 24 semanas)" => false, "No dispuesto a limitar exposición UV" => false
    }
    profile.criteria_variables.each do |cv|
      patient.variable_values.create!(
        name: cv.name, value: answers[cv.name].to_s, value_type: cv.value_type,
        comparison_type: cv.comparison_type, variable_type: cv.variable_type,
        reference_value_1: cv.reference_value_1, reference_value_2: cv.reference_value_2
      )
    end
    profile.evaluate(patient)
  end
end
