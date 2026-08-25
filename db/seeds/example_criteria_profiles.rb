# Realistic eligibility profiles across many studies, so the criteria engine,
# the recruitment score and the public questionnaire all have something to chew
# on in a development database.
#
# Dev/demo only. Idempotent: re-running updates the same profiles in place.
#
# SHAPE OF EVERY PROFILE (this is the part that matters)
#
# Each profile is 25 criteria: 5 shared primary + 12 shared secondary + 8
# area-specific secondary.
#
# THE PRIMARY COUNT IS FIXED AT 5 (2 inclusion + 3 exclusion), NOT A PERCENTAGE.
# The primary criteria are exactly the questions a patient is asked on the
# public questionnaire, and that form has to stay short enough that somebody
# actually finishes it — so the ceiling is six, whatever the protocol's size.
# A 60-criterion protocol still gets 5 or 6 primary; the rest are secondary.
#
# Five is also the smallest count that lets the score show its own thresholds.
# The score is `passing primary / total primary`, so with N primary the only
# reachable values are multiples of 100/N: with 2 you get 0/50/100 and
# `:promising` (the >= 70% band) can NEVER occur, with 5 you get 0/20/…/100 and
# 80% lands in it. Drop below 5 and the demo stops demonstrating itself.
#
# ONLY THE PRIMARY CRITERIA CARRY A patient_prompt. Secondary rows have no
# prompt at all, and `CriteriaVariable.askable_to_patient` filters to primary
# regardless, so the data and the code agree instead of relying on whoever
# writes the prompts to remember. Asking a patient about complementary criteria
# would lengthen the form without being able to move the outcome.
#
# The 5 primary criteria are shared across every area on purpose, and every one
# of them is something a PATIENT can answer about themselves. Auto-triage fires
# only when a patient's declarations satisfy EVERY primary criterion, so a
# single investigator-only primary rule (a lab value, an imaging result) would
# silently make auto-triage impossible for that study. Anything that needs a
# clinic to measure it — HbA1c, VEF1, joint counts — is secondary for exactly
# that reason: the patient is never asked, never penalised for not knowing.
#
# Each prompt asks for the RAW FACT, never the threshold. "¿Cuántos años
# tienes?", never "¿Tienes entre 18 y 75 años?" — the second leaks the protocol
# and turns the questionnaire into an oracle to optimise against.
#
#   ExampleCriteriaProfiles.seed!            # profiles for every study that lacks one
#   ExampleCriteriaProfiles.seed!(Study.limit(10))
module ExampleCriteriaProfiles
  # [variable_type, name, value_type, comparison_type, ref1, ref2, patient_prompt]
  # The trailing patient_prompt appears on PRIMARY rows only — those are the
  # only ones the public questionnaire asks. Secondary rows stop at ref2.

  # Decisive AND patient-answerable — see the header for why those two go together.
  CORE_PRIMARY = [
    [ "inclusion", "Edad (años)", "quantitative", "between_range", 18, 75,
      "¿Cuántos años tienes?" ],
    [ "inclusion", "Diagnóstico confirmado por un médico", "boolean", "true", nil, nil,
      "¿Un médico te ha diagnosticado esta enfermedad?" ],
    [ "exclusion", "Embarazo o lactancia", "boolean", "true", nil, nil,
      "¿Estás embarazada o en período de lactancia?" ],
    [ "exclusion", "Infección activa (últimas 2 semanas)", "boolean", "true", nil, nil,
      "¿Has tenido una infección que necesitara antibióticos en las últimas dos semanas?" ],
    [ "exclusion", "Participación en otro estudio (últimas 12 semanas)", "boolean", "true", nil, nil,
      "¿Participas o has participado en otro estudio clínico en los últimos tres meses?" ]
  ].freeze

  CORE_SECONDARY = [
    [ "inclusion", "Dispuesto a firmar el consentimiento informado", "boolean", "true", nil, nil ],
    [ "inclusion", "Disponibilidad para visitas presenciales", "boolean", "true", nil, nil ],
    [ "inclusion", "Residencia cercana al centro", "boolean", "true", nil, nil ],
    [ "inclusion", "Método anticonceptivo en edad fértil", "boolean", "true", nil, nil ],
    [ "inclusion", "Duración de la enfermedad (meses)", "quantitative", "more_than_or_equal", 6, nil ],
    [ "exclusion", "Enfermedad hepática o renal grave", "boolean", "true", nil, nil ],
    [ "exclusion", "Antecedente de cáncer (últimos 5 años)", "boolean", "true", nil, nil ],
    [ "exclusion", "Inmunosupresión conocida", "boolean", "true", nil, nil ],
    [ "exclusion", "Abuso de alcohol o drogas (últimas 24 semanas)", "boolean", "true", nil, nil ],
    [ "exclusion", "Trastorno psiquiátrico no controlado", "boolean", "true", nil, nil ],
    [ "exclusion", "Condición que impide adherencia (juicio del investigador)", "boolean", "true", nil, nil ],
    [ "exclusion", "Hipersensibilidad conocida a medicamentos", "boolean", "true", nil, nil ]
  ].freeze

  # Eight area-specific complementary criteria each. The clinic-measured ones
  # (HbA1c, presión, VEF1, recuento articular) live here rather than in
  # CORE_PRIMARY precisely because a patient cannot be expected to know them.
  AREAS = {
    "Diabetes tipo 2" => [
      [ "inclusion", "HbA1c (%)", "quantitative", "between_range", 7, 10 ],
      [ "inclusion", "Peso corporal (kg)", "quantitative", "between_range", 60, 120 ],
      [ "inclusion", "Tratamiento con metformina estable (≥3 meses)", "boolean", "true", nil, nil ],
      [ "inclusion", "Glucemia en ayunas (mg/dL)", "quantitative", "between_range", 130, 270 ],
      [ "exclusion", "Diabetes tipo 1", "boolean", "true", nil, nil ],
      [ "exclusion", "Uso actual de insulina", "boolean", "true", nil, nil ],
      [ "exclusion", "Cetoacidosis u hospitalización (último año)", "boolean", "true", nil, nil ],
      [ "exclusion", "Retinopatía diabética proliferativa", "boolean", "true", nil, nil ]
    ],
    "Hipertensión arterial" => [
      [ "inclusion", "Presión arterial sistólica (mmHg)", "quantitative", "between_range", 140, 180 ],
      [ "inclusion", "Presión arterial diastólica (mmHg)", "quantitative", "between_range", 90, 110 ],
      [ "inclusion", "Tratamiento antihipertensivo estable (≥4 semanas)", "boolean", "true", nil, nil ],
      [ "inclusion", "Acceso a automedición domiciliaria", "boolean", "true", nil, nil ],
      [ "exclusion", "Hipertensión secundaria conocida", "boolean", "true", nil, nil ],
      [ "exclusion", "Infarto o ACV (últimos 6 meses)", "boolean", "true", nil, nil ],
      [ "exclusion", "Insuficiencia cardíaca avanzada", "boolean", "true", nil, nil ],
      [ "exclusion", "Arritmia no controlada", "boolean", "true", nil, nil ]
    ],
    "Asma moderada a grave" => [
      [ "inclusion", "VEF1 (% del predicho)", "quantitative", "between_range", 50, 85 ],
      [ "inclusion", "Exacerbaciones en el último año", "quantitative", "more_than_or_equal", 1, nil ],
      [ "inclusion", "Uso de corticoide inhalado (≥3 meses)", "boolean", "true", nil, nil ],
      [ "inclusion", "Diagnóstico de asma hace más de 12 meses", "boolean", "true", nil, nil ],
      [ "exclusion", "EPOC concomitante", "boolean", "true", nil, nil ],
      [ "exclusion", "Tabaquismo activo", "boolean", "true", nil, nil ],
      [ "exclusion", "Hospitalización por asma (últimas 6 semanas)", "boolean", "true", nil, nil ],
      [ "exclusion", "Uso crónico de corticoide oral", "boolean", "true", nil, nil ]
    ],
    "Artritis reumatoide" => [
      [ "inclusion", "Articulaciones inflamadas (recuento)", "quantitative", "more_than_or_equal", 6, nil ],
      [ "inclusion", "Factor reumatoide o anti-CCP positivo", "boolean", "true", nil, nil ],
      [ "inclusion", "Tratamiento con metotrexato estable (≥3 meses)", "boolean", "true", nil, nil ],
      [ "inclusion", "Rigidez matinal (minutos)", "quantitative", "more_than_or_equal", 30, nil ],
      [ "exclusion", "Otra enfermedad autoinmune activa", "boolean", "true", nil, nil ],
      [ "exclusion", "Tuberculosis latente no tratada", "boolean", "true", nil, nil ],
      [ "exclusion", "Cirugía articular programada", "boolean", "true", nil, nil ],
      [ "exclusion", "Uso de biológicos (últimas 12 semanas)", "boolean", "true", nil, nil ]
    ]
  }.freeze

  AREA_NAMES = AREAS.keys.freeze

  # Outcomes the demo patients are built to land on, so a dev browsing the
  # patients index sees the whole spread rather than a wall of one colour.
  OUTCOMES = %i[ready promising blocked pending untouched].freeze

  # One profile per study (the DB enforces at most one), cycling the areas so a
  # dev sees several different rule sets. Studies that already own a profile are
  # left alone — that includes the seborrheic-dermatitis example.
  def self.seed!(studies = Study.all, owner: nil)
    owner ||= User.admins.first || FactoryBot.create(:user, :admin)
    created = 0

    studies.each_with_index do |study, index|
      next if study.criteria_profile.present?

      area = AREA_NAMES[index % AREA_NAMES.size]
      profile = build_profile!(study, area, owner)
      populate_answers!(profile)
      created += 1
    end

    created
  end

  def self.build_profile!(study, area, owner)
    profile = CriteriaProfile.create!(
      study: study, user: owner,
      name: "#{area} — criterios de inclusión/exclusión",
      description: "Perfil de ejemplo (#{area}) para el estudio «#{study.short_title}»."
    )

    rows = CORE_PRIMARY.map { |r| [ r, "primary" ] } +
           (CORE_SECONDARY + AREAS.fetch(area)).map { |r| [ r, "secondary" ] }

    rows.each_with_index do |((variable_type, name, value_type, comparison_type, ref1, ref2, prompt), category), i|
      profile.criteria_variables.create!(
        name: name, variable_type: variable_type, value_type: value_type,
        comparison_type: comparison_type, criteria_category: category,
        reference_value_1: ref1, reference_value_2: ref2,
        patient_prompt: prompt, criteria_order: i + 1
      )
    end

    profile
  end

  # Give the study's patients investigator-recorded values, spread across the
  # recruitment outcomes. Deliberately NOT every patient: leaving some with no
  # values at all is realistic (nobody has assessed them yet) and it exercises
  # the `:pending` / unmeasured path.
  def self.populate_answers!(profile)
    variables = profile.criteria_variables.to_a
    primary = variables.select(&:primary?)
    secondary = variables.reject(&:primary?)

    profile.study.patients.each_with_index do |patient, i|
      outcome = OUTCOMES[i % OUTCOMES.size]
      next if outcome == :untouched

      answers = {}
      # Secondary criteria: mostly satisfied, with the occasional unmet one so
      # the advisory warning has something to say.
      secondary.each do |cv|
        answers[cv] = rand < 0.15 ? failing_value(cv) : passing_value(cv)
      end

      case outcome
      when :ready
        primary.each { |cv| answers[cv] = passing_value(cv) }
      when :promising
        # 4 of 5 pass, the fifth simply unmeasured -> 80%, nothing ruled out.
        primary.each_with_index { |cv, n| answers[cv] = passing_value(cv) unless n.zero? }
      when :blocked
        # Every primary criterion measured and passing except one, which
        # measurably fails: the score stays high and it is blocked anyway.
        primary.each { |cv| answers[cv] = passing_value(cv) }
        if (decisive = primary.sample)
          answers[decisive] = failing_value(decisive)
        end
      when :pending
        primary.first(2).each { |cv| answers[cv] = passing_value(cv) }
      end

      write_values!(patient, answers)
    end
  end

  # A value the rule is SATISFIED by. For an inclusion criterion that is what
  # passing looks like; for an exclusion it is the opposite (see passing_value).
  def self.satisfying_value(cv)
    return "true" if cv.value_type == "boolean"

    r1 = cv.reference_value_1.to_f
    r2 = cv.reference_value_2.to_f
    case cv.comparison_type
    when "between_range"          then ((r1 + r2) / 2).round(1)
    when "more_than_or_equal"     then (r1 + 1).round(1)
    when "more_than"              then (r1 + 1).round(1)
    when "less_than_or_equal"     then (r1 - 1).round(1)
    when "less_than"              then (r1 - 1).round(1)
    when "equal"                  then r1.round(1)
    else (r1 + 1).round(1)
    end
  end

  def self.violating_value(cv)
    return "false" if cv.value_type == "boolean"

    r1 = cv.reference_value_1.to_f
    case cv.comparison_type
    when "between_range", "more_than_or_equal", "more_than" then (r1 - 5).round(1)
    when "less_than_or_equal", "less_than"                  then (r1 + 5).round(1)
    when "equal"                                            then (r1 + 1).round(1)
    else (r1 - 5).round(1)
    end
  end

  # An inclusion criterion passes when the patient MEETS it; an exclusion passes
  # when the patient does NOT (EligibilityResult::Check#passed?).
  def self.passing_value(cv)
    cv.variable_type == "inclusion" ? satisfying_value(cv) : violating_value(cv)
  end

  def self.failing_value(cv)
    cv.variable_type == "inclusion" ? violating_value(cv) : satisfying_value(cv)
  end

  # Mirrors CriteriaAssessmentsController#update: matched to the rule by FK,
  # with the rule snapshotted onto the answer (including how decisive it was at
  # the time it was captured).
  def self.write_values!(patient, answers)
    answers.each do |cv, raw|
      record = patient.variable_values.find_by(criteria_variable_id: cv.id) ||
               patient.variable_values.build(criteria_variable: cv)
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

  # Patient testimony for studies whose questionnaire is switched on: a handful
  # of `interested` patients answer the primary questions themselves. Where the
  # answers satisfy every primary criterion this triages them exactly as the
  # controller does — under a system whodunnit, because the system really is
  # what moved them.
  def self.declare!(profile, patients)
    askable = profile.criteria_variables.askable_to_patient.to_a
    return if askable.empty?

    patients.each do |patient|
      askable.each do |cv|
        next if rand < 0.1 # some questions simply left blank

        declined = rand < 0.1
        patient.patient_declarations.create!(
          criteria_variable: cv, prompt: cv.patient_prompt,
          answer: declined ? nil : passing_value(cv).to_s,
          declined: declined, value_type: cv.value_type,
          qualitative_scale: cv.qualitative_scale,
          capture_mode: "public_form", declared_at: Time.current
        )
      end

      patient.reload
      next unless patient.interested? && patient.primary_criteria_met_by_self_report?

      PaperTrail.request(whodunnit: "system:self-report-triage") do
        patient.assess! if patient.may_assess?
      end
    end
  end
end
