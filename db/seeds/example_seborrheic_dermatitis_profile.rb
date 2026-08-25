# Example eligibility profile modeled from a real severe seborrheic-dermatitis
# protocol, to demonstrate the CriteriaProfile / CriteriaVariable engine, the
# evaluator, and — the point of the demo patients below — how the primary /
# secondary split drives the recruitment score.
#
# Idempotent. Dev/demo only — not wired into db/seeds.rb by default (it creates
# an admin-owned example profile, a sponsor, a study and sample patients).
# Run manually:
#
#   require_relative "db/seeds/example_seborrheic_dermatitis_profile"
#   profile = ExampleSeborrheicDermatitisProfile.seed!
#   ExampleSeborrheicDermatitisProfile.demo!(profile)   # 4 patients, one per recommendation
#
# ...or in one step, which also prints the resulting scores:
#
#   ExampleSeborrheicDermatitisProfile.report!
#
# TWO THINGS THIS FILE DEMONSTRATES ON PURPOSE
#
# 1. A SMALL, FIXED primary set: 2 inclusion + 3 exclusion = 5, out of 25
#    criteria. The count is fixed deliberately rather than derived from a
#    percentage of the protocol — the primary criteria are the ones a patient is
#    asked about, and a public questionnaire has to stay short enough that
#    somebody actually finishes it. Six is the ceiling; five is what this
#    protocol needs. The other 20 are `secondary`: measured by the centre,
#    shown, part of the whole-protocol verdict, but never able on their own to
#    promote or hold back a patient.
#
#    Five also happens to be the smallest primary count that lets the score show
#    its own thresholds: the score is `passing primary / total primary`, so with
#    N primary the only reachable values are multiples of 100/N. With 2 you get
#    0/50/100 and `:promising` (the >= 70% band) can never occur; with 5, 80%
#    lands in it and all four recommendations are reachable.
#
# 2. ONLY the primary criteria carry a `patient_prompt`, so those five are
#    exactly what the public step-2 questionnaire asks. Secondary rules have no
#    prompt at all and `CriteriaVariable.askable_to_patient` filters to primary
#    anyway, so the two agree. The prompt is the ONLY thing the patient ever
#    sees — never the rule name, the comparison or the reference values — so
#    each is written in patient language and asks for the raw fact, never for
#    the threshold. "¿Cuántos años tienes?", never "¿Tienes entre 18 y 75
#    años?": the second leaks the protocol and turns the form into an oracle to
#    optimise against.
#
#    All five PRIMARY criteria are things a patient can honestly answer about
#    themselves. That is what makes auto-triage possible: it fires only when the
#    declarations satisfy EVERY primary criterion, so a single primary rule that
#    only an investigator could measure would silently prevent it forever. The
#    clinic-measured ones (IGA score, BSA%) are secondary for exactly this
#    reason — the patient is never asked, and never penalised for not knowing.
module ExampleSeborrheicDermatitisProfile
  PROFILE_NAME = "Dermatitis seborreica grave — criterios de inclusión/exclusión".freeze
  STUDY_TITLE = "Estudio de terapia sistémica en dermatitis seborreica grave".freeze

  # [name, value_type, comparison_type, reference_value_1, reference_value_2,
  #  criteria_category, patient_prompt]
  INCLUSION = [
    [ "Edad (años)", "quantitative", "between_range", 18, 75, "primary",
      "¿Cuántos años tienes?" ],
    [ "Diagnóstico confirmado de dermatitis seborreica", "boolean", "true", nil, nil, "primary",
      "¿Un médico te ha diagnosticado dermatitis seborreica?" ],
    [ "Duración de la enfermedad (meses)", "quantitative", "more_than_or_equal", 3, nil, "secondary" ],
    [ "Puntuación de severidad (IGA)", "quantitative", "more_than_or_equal", 3, nil, "secondary" ],
    [ "Afectación BSA (%)", "quantitative", "more_than_or_equal", 10, nil, "secondary" ],
    [ "Candidato a terapia sistémica", "boolean", "true", nil, nil, "secondary" ],
    [ "Ha fracasado al menos un tratamiento tópico", "boolean", "true", nil, nil, "secondary" ],
    [ "Dispuesto a firmar el consentimiento informado", "boolean", "true", nil, nil, "secondary" ],
    [ "Disponibilidad para visitas presenciales", "boolean", "true", nil, nil, "secondary" ],
    [ "Método anticonceptivo en edad fértil", "boolean", "true", nil, nil, "secondary" ]
  ].freeze

  EXCLUSION = [
    [ "Infección sistémica activa (últimas 2 semanas)", "boolean", "true", nil, nil, "primary",
      "¿Has tenido una infección que necesitara antibióticos en las últimas dos semanas?" ],
    [ "Embarazo o lactancia", "boolean", "true", nil, nil, "primary",
      "¿Estás embarazada o en período de lactancia?" ],
    [ "Participación en otro estudio clínico (últimas 12 semanas)", "boolean", "true", nil, nil, "primary",
      "¿Participas o has participado en otro estudio clínico en los últimos tres meses?" ],
    [ "Hipersensibilidad o alergia al medicamento del estudio", "boolean", "true", nil, nil, "secondary" ],
    [ "Planes de vacunas vivas", "boolean", "true", nil, nil, "secondary" ],
    [ "Condición que impide adherencia (juicio del investigador)", "boolean", "true", nil, nil, "secondary" ],
    [ "Abuso de alcohol o drogas (últimas 24 semanas)", "boolean", "true", nil, nil, "secondary" ],
    [ "No dispuesto a limitar exposición UV", "boolean", "true", nil, nil, "secondary" ],
    [ "Tratamiento sistémico en las últimas 4 semanas", "boolean", "true", nil, nil, "secondary" ],
    [ "Inmunosupresión conocida", "boolean", "true", nil, nil, "secondary" ],
    [ "Enfermedad hepática o renal grave", "boolean", "true", nil, nil, "secondary" ],
    [ "Antecedente de cáncer (últimos 5 años)", "boolean", "true", nil, nil, "secondary" ],
    [ "Otra enfermedad cutánea que interfiera la evaluación", "boolean", "true", nil, nil, "secondary" ],
    [ "Tabaquismo activo", "boolean", "true", nil, nil, "secondary" ],
    [ "Trastorno psiquiátrico no controlado", "boolean", "true", nil, nil, "secondary" ]
  ].freeze

  ALL_VARIABLES = (INCLUSION.map { |r| [ "inclusion", r ] } +
                   EXCLUSION.map { |r| [ "exclusion", r ] }).freeze

  # A patient who satisfies every criterion, primary and secondary alike.
  # Each scenario below is this set with a few answers changed.
  BASE_ANSWERS = {
    "Edad (años)" => 34,
    "Diagnóstico confirmado de dermatitis seborreica" => true,
    "Duración de la enfermedad (meses)" => 8,
    "Puntuación de severidad (IGA)" => 3,
    "Afectación BSA (%)" => 15,
    "Candidato a terapia sistémica" => true,
    "Ha fracasado al menos un tratamiento tópico" => true,
    "Dispuesto a firmar el consentimiento informado" => true,
    "Disponibilidad para visitas presenciales" => true,
    "Método anticonceptivo en edad fértil" => true,
    "Infección sistémica activa (últimas 2 semanas)" => false,
    "Embarazo o lactancia" => false,
    "Participación en otro estudio clínico (últimas 12 semanas)" => false,
    "Hipersensibilidad o alergia al medicamento del estudio" => false,
    "Planes de vacunas vivas" => false,
    "Condición que impide adherencia (juicio del investigador)" => false,
    "Abuso de alcohol o drogas (últimas 24 semanas)" => false,
    "No dispuesto a limitar exposición UV" => false,
    "Tratamiento sistémico en las últimas 4 semanas" => false,
    "Inmunosupresión conocida" => false,
    "Enfermedad hepática o renal grave" => false,
    "Antecedente de cáncer (últimos 5 años)" => false,
    "Otra enfermedad cutánea que interfiera la evaluación" => false,
    "Tabaquismo activo" => false,
    "Trastorno psiquiátrico no controlado" => false
  }.freeze

  # One demo patient per EligibilityResult#recommendation. A `nil` answer means
  # "not measured yet", which is exactly how an unmeasured criterion holds the
  # score down. Keyed by the recommendation each is built to produce.
  #
  # The five primary criteria are: Edad, Diagnóstico confirmado, Infección
  # sistémica activa, Embarazo o lactancia, Participación en otro estudio.
  SCENARIOS = {
    # 5/5 primary criteria pass → 100%. A *secondary* exclusion is triggered, so
    # the whole-protocol verdict is "not eligible" while the recruitment score
    # still says promote: the disagreement is the feature, not a bug.
    ready: { "Planes de vacunas vivas" => true },

    # 4 of 5 primary criteria pass and the fifth is simply unmeasured → 80%,
    # nothing decisive ruled out: worth a rep's attention, not yet promotable.
    promising: { "Participación en otro estudio clínico (últimas 12 semanas)" => nil },

    # A primary exclusion is triggered. Four other primary criteria still pass,
    # so the raw percentage is high — and it does not matter: one decisive
    # failure blocks promotion outright.
    blocked: { "Infección sistémica activa (últimas 2 semanas)" => true },

    # Only 2 of 5 primary criteria measured → 40%. Too early to say anything.
    pending: {
      "Diagnóstico confirmado de dermatitis seborreica" => nil,
      "Embarazo o lactancia" => nil,
      "Participación en otro estudio clínico (últimas 12 semanas)" => nil
    }
  }.freeze

  DEMO_FIRSTNAME = "Demo".freeze

  def self.seed!
    owner = User.admins.first || FactoryBot.create(:user, :admin)
    study = demo_study!

    profile = CriteriaProfile.find_or_create_by!(name: PROFILE_NAME, user: owner) do |p|
      p.description = "Ejemplo a partir de un protocolo de dermatitis seborreica grave."
      p.study = study
    end
    # Re-attach on re-runs: an existing profile from an earlier seeding may have
    # been created before the study existed.
    profile.update!(study: study) if profile.study.nil?

    order = 0
    ALL_VARIABLES.each do |variable_type, (name, value_type, comparison_type, ref1, ref2, category, prompt)|
      order += 1
      variable = profile.criteria_variables.find_or_initialize_by(name: name)
      variable.assign_attributes(
        variable_type: variable_type, value_type: value_type, comparison_type: comparison_type,
        criteria_category: category, patient_prompt: prompt,
        reference_value_1: ref1, reference_value_2: ref2, criteria_order: order
      )
      variable.save!
    end

    profile
  end

  # The profile needs a study to hang off (a Patient must belong to one), and the
  # public step-2 questionnaire only exists for a study whose question wording is
  # approved — so the demo turns that switch on explicitly. There is no UI for
  # `patient_self_report_enabled` yet, which is exactly why seeding it matters:
  # without this line the questionnaire is unreachable in a fresh dev database.
  def self.demo_study!
    study = Study.find_by(short_title: STUDY_TITLE) || FactoryBot.create(
      :study,
      sponsor: Sponsor.first || FactoryBot.create(:sponsor),
      short_title: STUDY_TITLE,
      public_title: "¿Convives con dermatitis seborreica grave?",
      scientific_title: STUDY_TITLE,
      study_status: "recruiting",
      study_type: "interventional",
      sample_size: 20
    )
    study.update!(patient_self_report_enabled: true) unless study.patient_self_report_enabled?
    study
  end

  # Build (or refresh) one patient per scenario and return their evaluations,
  # keyed by scenario name. Idempotent: re-running updates the same patients.
  def self.demo!(profile = seed!)
    if profile.study.nil?
      raise "The example profile has no study, and a Patient must belong to one. " \
            "Create a Study first, then re-run seed!."
    end

    SCENARIOS.to_h do |scenario, overrides|
      patient = demo_patient!(profile, scenario)
      apply_answers!(profile, patient, BASE_ANSWERS.merge(overrides))
      [ scenario, profile.evaluate(patient.reload) ]
    end
  end

  # demo! plus a printed summary — the quickest way to see the split at work.
  def self.report!
    profile = seed!
    primary, secondary = profile.criteria_variables.partition(&:primary?)
    puts format("profile: %d variables — %d primary (%d%%), %d secondary, %d askable to patients",
                profile.criteria_variables.count, primary.size,
                (primary.size.to_f / profile.criteria_variables.count * 100).round,
                secondary.size, profile.criteria_variables.select(&:askable_to_patient?).size)

    demo!(profile).each do |scenario, result|
      puts format(
        "%-10s score=%3d%% (%d/%d primary answered)  recommendation=%-10s verdict=%s%s",
        scenario, result.primary_score, result.primary_answered_count, result.primary_total_count,
        result.recommendation, result.verdict,
        result.secondary_concerns.any? ? "  [#{result.secondary_concerns.count} secondary not met]" : ""
      )
    end
    profile
  end

  # A patient per scenario, identified by name so re-runs reuse the same row
  # (firstname/lastname are deterministically encrypted, so they are queryable).
  def self.demo_patient!(profile, scenario)
    Patient.find_or_create_by!(firstname: DEMO_FIRSTNAME, lastname: scenario.to_s.capitalize) do |p|
      p.study = profile.study
      p.contact_number = "+57 300 000 0000"
      p.sex = "female"
      p.dob = Date.new(1990, 1, 1)
    end
  end

  # Upsert the patient's answers, mirroring CriteriaAssessmentsController#update:
  # matched to the rule by FK, with the rule copied onto the answer (snapshot
  # design — including how decisive the rule was when captured). A nil answer
  # removes any existing value, so the criterion reads as still-to-measure.
  def self.apply_answers!(profile, patient, answers)
    profile.criteria_variables.each do |cv|
      raw = answers[cv.name]
      record = patient.variable_values.find_by(criteria_variable_id: cv.id)

      if raw.nil?
        record&.destroy!
        next
      end

      record ||= patient.variable_values.build(criteria_variable: cv)
      record.assign_attributes(
        name: cv.name, value: raw.to_s,
        value_type: cv.value_type, comparison_type: cv.comparison_type,
        variable_type: cv.variable_type, criteria_category: cv.criteria_category,
        reference_value_1: cv.reference_value_1, reference_value_2: cv.reference_value_2,
        qualitative_value: cv.qualitative_value, qualitative_scale: cv.qualitative_scale,
        criteria_order: cv.criteria_order
      )
      record.save!
    end
  end
end
