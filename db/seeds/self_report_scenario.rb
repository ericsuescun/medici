# A fixed study for walking the public questionnaire end to end, by hand, in a
# browser: step 1 → step 2 → auto-triage → the rep's review → `potential`.
# Development only. `db/seeds.rb` builds it; the rake task rebuilds it and
# prints the cheat sheet:
#
#   bin/rails scenarios:self_report            # build or refresh, print the cheat sheet
#   RESET=1 bin/rails scenarios:self_report    # same, but wipe ALL its patients (hand-made ones too) and re-seed the examples
#
# WHY THIS EXISTS. The seeded profiles could not exercise the two-tier
# questionnaire: `ExampleCriteriaProfiles.seed!` skips any study that already
# has a profile, so a database seeded before 2026-10-04 (when specific criteria
# became askable) asked five basic questions per study and not one specific
# question anywhere. Random seed data also gives no way to know in advance which
# answer should pass.
#
# Everything here is fixed instead, and the cheat sheet says for every question
# which answer passes and which fails. The profile is deliberately small and
# covers each case the questionnaire has to get right:
#
#   * 5 basic questions          — page 1; all satisfied → auto-triage to candidate
#   * 4 specific WITH a prompt   — page 2, only if page 1 matched; testimony, move nobody
#   * 3 specific WITHOUT one     — never asked; only a rep can record them
#   * every value type           — number, Sí/No, and one qualitative select
#
# EXAMPLES then seeds one patient per stage of the flow, so the rep's side can
# be looked at without filling the public form eight times first.
#
# Its own facility, branch, sponsor and rep, so the rep's patient list shows
# this study's patients and nothing else. `spec/requests/self_report_scenario_spec.rb`
# walks every promise the cheat sheet makes, so it cannot quietly go stale.
module SelfReportScenario
  STUDY_SHORT_TITLE = "Escenario de prueba — cuestionario".freeze
  STUDY_PUBLIC_TITLE = "[PRUEBA] ¿Tienes migraña frecuente?".freeze
  SPONSOR_NAME = "[PRUEBA] Patrocinador del cuestionario".freeze
  FACILITY_NAME = "[PRUEBA] Centro del cuestionario".freeze
  BRANCH_NAME = "[PRUEBA] Sede del cuestionario".freeze
  PROFILE_NAME = "[PRUEBA] Migraña — escenario del cuestionario".freeze
  REP_EMAIL = "rep.cuestionario@medici.test".freeze
  PASSWORD = "12345678".freeze
  EXAMPLE_IP = "127.0.0.1".freeze

  INTENSITY_SCALE = %w[Leve Moderada Intensa].freeze

  # [category, variable_type, name, value_type, comparison, ref1, ref2, prompt, pass, fail]
  #
  # `pass`/`fail` are raw values, exactly as both forms submit them ("true" /
  # "false" for Sí/No). For an exclusion, "pass" means NOT excluded. The
  # qualitative row keeps its expected value in ref1; its scale is above.
  CRITERIA = [
    [ "basic", "inclusion", "Edad (años)", "quantitative", "between_range", 18, 65,
      "¿Cuántos años tienes?", "40", "70" ],
    [ "basic", "inclusion", "Diagnóstico de migraña por un médico", "boolean", "true", nil, nil,
      "¿Un médico te ha diagnosticado migraña?", "true", "false" ],
    [ "basic", "exclusion", "Embarazo o lactancia", "boolean", "true", nil, nil,
      "¿Estás embarazada o en período de lactancia?", "false", "true" ],
    [ "basic", "exclusion", "Participación en otro estudio (últimas 12 semanas)", "boolean", "true", nil, nil,
      "¿Participas o has participado en otro estudio clínico en los últimos tres meses?", "false", "true" ],
    [ "basic", "exclusion", "Infección activa (últimas 2 semanas)", "boolean", "true", nil, nil,
      "¿Has tenido una infección que necesitara antibióticos en las últimas dos semanas?", "false", "true" ],

    [ "specific", "inclusion", "Días con migraña al mes", "quantitative", "more_than_or_equal", 4, nil,
      "¿Cuántos días al mes tienes migraña?", "8", "2" ],
    [ "specific", "inclusion", "Intensidad habitual del dolor", "qualitative", "different", "Leve", nil,
      "¿Qué tan fuerte suele ser el dolor?", "Intensa", "Leve" ],
    [ "specific", "inclusion", "Disponibilidad para visitas presenciales", "boolean", "true", nil, nil,
      "¿Podrías asistir a las visitas presenciales que exige el estudio?", "true", "false" ],
    [ "specific", "exclusion", "Uso de opioides para la cefalea", "boolean", "true", nil, nil,
      "¿Tomas opioides (como tramadol o codeína) para el dolor de cabeza?", "false", "true" ],

    [ "specific", "inclusion", "Diario de cefaleas completo ≥ 80% (selección)", "boolean", "true", nil, nil,
      nil, "true", "false" ],
    [ "specific", "exclusion", "Presión arterial sistólica (mmHg)", "quantitative", "more_than", 160, nil,
      nil, "125", "170" ],
    [ "specific", "exclusion", "Alteración en el ECG de selección", "boolean", "true", nil, nil,
      nil, "false", "true" ]
  ].freeze

  # One patient per stage of the flow, every one built through the calls the app
  # itself makes — declarations then sync, recorded values then sync, `accept!`
  # — so `expected` is what the engine computes, never a write to the column.
  #
  #   asked:    which questions they answered — :all (both pages), :basic (page 1
  #             only: ruled out there, or stopped before page 2), or nil (never
  #             reached the questionnaire)
  #   answers:  per-question overrides on top of that — :fail, :blank, :dont_know, or
  #             :pass to answer one outside the base set
  #   measured: what the rep recorded — :all (every criterion, passing), or a Hash
  #             of name => :pass/:fail for just those
  #   accept:   the rep pressed «Aceptar» afterwards
  EXAMPLES = [
    { code: "PRUEBA-A", firstname: "Ana", lastname: "Autotriada", asked: :all,
      expected: "candidate",
      story: "Respondió todo en PASA: el sistema la pasó a Candidato. 4/7 declarados." },
    { code: "PRUEBA-H", firstname: "Hugo", lastname: "Pocas Respuestas", asked: :basic,
      answers: { "Disponibilidad para visitas presenciales" => :pass },
      expected: "candidate",
      story: "Básicas en PASA; en la página 2 respondió una sola: Candidato con 1/7, debajo de Ana." },
    { code: "PRUEBA-B", firstname: "Beto", lastname: "Excluido", asked: :basic,
      answers: { "Infección activa (últimas 2 semanas)" => :fail },
      expected: "interested",
      story: "Una básica en FALLA (infección): terminó en la página 1; Interesado, sin específicas." },
    { code: "PRUEBA-C", firstname: "Caro", lastname: "Incompleta", asked: :basic,
      answers: { "Edad (años)" => :blank, "Diagnóstico de migraña por un médico" => :dont_know },
      expected: "interested",
      story: "Edad en blanco y «No sé» en el diagnóstico: igual que Beto, mismo mensaje." },
    { code: "PRUEBA-G", firstname: nil, lastname: nil, asked: nil,
      expected: "interested",
      story: "Solo dejó su teléfono, sin nombre: la lista la muestra por su código." },
    { code: "PRUEBA-D", firstname: "Dani", lastname: "Medida", asked: :all, measured: :all,
      expected: "candidate",
      story: "Autotriada y el rep registró los 12 valores: «Aceptar» habilitado, primera de la cola." },
    { code: "PRUEBA-E", firstname: "Elena", lastname: "Potencial", asked: :all, measured: :all, accept: true,
      expected: "potential",
      story: "Como Dani, y el rep pulsó «Aceptar»: está en Potenciales, no en la lista principal." },
    { code: "PRUEBA-F", firstname: "Fede", lastname: "Degradado", asked: :all,
      measured: { "Edad (años)" => :fail },
      expected: "interested",
      story: "Declaró 40 años y quedó Candidato; el rep midió 70: el sistema lo devolvió a Interesado." }
  ].freeze

  def self.build!(reset: false)
    owner = User.admins.first or raise "No admin user — run bin/rails db:seed first."

    study = study!
    rep = rep!(study)
    profile = profile!(study, owner)
    wiped = reset ? wipe_patients!(study) : 0
    seeded = examples!(study, profile, rep)

    { study: study, rep: rep, profile: profile, wiped: wiped, seeded: seeded }
  end

  def self.study!
    sponsor = Sponsor.find_or_create_by!(name: SPONSOR_NAME) do |s|
      s.initials = "PRB"
      s.shortname = "Prueba"
      s.sponsor_type = "private_type"
    end

    study = Study.find_or_initialize_by(short_title: STUDY_SHORT_TITLE)
    study.assign_attributes(
      sponsor: sponsor,
      public_title: STUDY_PUBLIC_TITLE,
      scientific_title: "Estudio ficticio para probar el cuestionario de autoevaluación",
      inclusion_criteria: "Ver el perfil de criterios.",
      exclusion_criteria: "Ver el perfil de criterios.",
      main_intervention: "Ninguna — estudio de prueba",
      study_status: "recruiting",
      study_type: "interventional",
      study_phase: "III",
      local_health_authority_approved: true,
      sample_size: 20,
      sex: "both",
      patient_self_report_enabled: true
    )
    study.save!

    branch = branch!
    study.trial_center_branches << branch unless study.trial_center_branches.include?(branch)
    study
  end

  def self.branch!
    facility = TrialCenterFacility.find_or_create_by!(name: FACILITY_NAME) do |f|
      f.initials = "PRB"
      f.email = "centro.cuestionario@medici.test"
    end
    branch = TrialCenterBranch.find_or_create_by!(name: BRANCH_NAME, trial_center_facility: facility) do |b|
      b.initials = "PRB"
      b.email = "sede.cuestionario@medici.test"
    end
    city = City.find_or_create_by!(name: "Bogotá")
    branch.cities << city unless branch.cities.include?(city)
    branch
  end

  # A trial centre rep on the scenario's own branch, active (accounts are
  # inactive by default and could not sign in otherwise). Re-runs reset the
  # password, so the cheat sheet is always right.
  def self.rep!(study)
    branch = study.trial_center_branches.find_by!(name: BRANCH_NAME)
    user = User.find_by(email: REP_EMAIL) ||
           User.new(email: REP_EMAIL, firstname: "Rep", lastname: "Cuestionario",
                    userable: TrialCenterBranchRep.new(trial_center_branch: branch, title: "Coordinadora"))
    user.assign_attributes(password: PASSWORD, password_confirmation: PASSWORD, active: true)
    user.save!
    user
  end

  # Matches rules by NAME so re-runs update in place rather than duplicating,
  # and deletes any rule no longer listed so the profile is exactly CRITERIA.
  def self.profile!(study, owner)
    profile = study.criteria_profile ||
              CriteriaProfile.create!(study: study, user: owner, name: PROFILE_NAME,
                                      description: "Perfil fijo para probar el cuestionario a mano.")

    CRITERIA.each_with_index do |(category, variable_type, name, value_type, comparison, ref1, ref2, prompt), i|
      cv = profile.criteria_variables.find_or_initialize_by(name: name)
      qualitative = value_type == "qualitative"
      cv.assign_attributes(
        criteria_category: category, variable_type: variable_type,
        value_type: value_type, comparison_type: comparison,
        reference_value_1: qualitative ? nil : ref1, reference_value_2: ref2,
        qualitative_value: qualitative ? ref1 : nil,
        qualitative_scale: qualitative ? INTENSITY_SCALE : [],
        patient_prompt: prompt, criteria_order: i + 1, enabled: true, shown: true
      )
      cv.save!
    end
    profile.criteria_variables.where.not(name: CRITERIA.map { |row| row[2] }).destroy_all

    profile.reload
  end

  # Only ever this study's patients — it is a fixture, not real recruitment.
  def self.wipe_patients!(study)
    patients = study.patients.to_a
    patients.each(&:destroy!)
    patients.size
  end

  # Missing examples only, found by their fixed participant code — so a re-run
  # leaves alone an example somebody has since moved by hand. RESET=1 is how to
  # get them back to where EXAMPLES says they start.
  def self.examples!(study, profile, rep)
    EXAMPLES.each_with_index.count do |spec, i|
      next false if Patient.exists?(participant_code: spec[:code])

      example!(spec, i, study, profile, rep)
      true
    end
  end

  def self.example!(spec, index, study, profile, rep)
    patient = Patient.create!(
      study: study, participant_code: spec[:code],
      firstname: spec[:firstname], lastname: spec[:lastname],
      contact_number: format("+57 300 555 %04d", index + 1),
      self_registered: true, adult_confirmed: true, reported_city: "Bogotá"
    )
    Consent.record_ley_1581!(patient, ip_address: EXAMPLE_IP)

    if spec[:asked]
      declare!(patient, profile, outcomes_for(spec[:asked], spec[:answers]))
      Consent.record_self_report!(patient, ip_address: EXAMPLE_IP)
      patient.sync_state_with_criteria!
    end

    if spec[:measured]
      measured = spec[:measured] == :all ? CRITERIA.to_h { |row| [ row[2], :pass ] } : spec[:measured]
      PaperTrail.request(whodunnit: rep.id.to_s) { measure!(patient, profile, rep, measured) }
      patient.sync_state_with_criteria!
    end

    PaperTrail.request(whodunnit: rep.id.to_s) { patient.reload.accept! } if spec[:accept]
    patient
  end

  # name => :pass/:fail/:blank/:dont_know for every question this example answers.
  def self.outcomes_for(asked, overrides)
    base = CRITERIA.select { |row| row[7].present? && (asked == :all || row[0] == "basic") }
    base.to_h { |row| [ row[2], :pass ] }.merge(overrides || {})
  end

  # As SelfReportsController#save_declarations! writes them — testimony, never values.
  def self.declare!(patient, profile, outcomes)
    outcomes.each do |name, outcome|
      next if outcome == :blank

      cv = profile.criteria_variables.find_by!(name: name)
      declined = outcome == :dont_know
      patient.patient_declarations.create!(
        criteria_variable: cv, prompt: cv.patient_prompt,
        answer: declined ? nil : raw_value(name, outcome),
        declined: declined, value_type: cv.value_type,
        qualitative_scale: cv.qualitative_scale,
        capture_mode: "public_form", declared_at: Time.current
      )
    end
  end

  # As CriteriaAssessmentsController#save_values! writes them, rule snapshotted.
  def self.measure!(patient, profile, rep, outcomes)
    outcomes.each do |name, outcome|
      cv = profile.criteria_variables.find_by!(name: name)
      record = patient.variable_values.find_or_initialize_by(criteria_variable_id: cv.id)
      record.entered_by ||= rep
      record.assign_attributes(
        name: cv.name, value: raw_value(name, outcome),
        value_type: cv.value_type, comparison_type: cv.comparison_type, variable_type: cv.variable_type,
        criteria_category: cv.criteria_category,
        reference_value_1: cv.reference_value_1, reference_value_2: cv.reference_value_2,
        qualitative_value: cv.qualitative_value, qualitative_scale: cv.qualitative_scale,
        criteria_order: cv.criteria_order
      )
      record.save!
    end
  end

  def self.raw_value(name, outcome)
    row = CRITERIA.find { |r| r[2] == name } or raise ArgumentError, "unknown criterion #{name.inspect}"
    { pass: row[8], fail: row[9] }.fetch(outcome)
  end

  # What a tester sees in the select, rather than its value.
  def self.shown(raw)
    { "true" => "Sí", "false" => "No" }.fetch(raw, raw)
  end

  def self.state_label(state)
    I18n.t("patients.states.#{state}", locale: :es)
  end

  # bin/dev runs the server through foreman, which hands it PORT=5000 unless
  # told otherwise — so 5000, not Rails' own 3000, is where the links must point.
  def self.report(built, host: "http://localhost:#{ENV.fetch('PORT', 5000)}")
    study, profile = built.values_at(:study, :profile)
    rows = CRITERIA.map { |row| [ profile.criteria_variables.find_by!(name: row[2]), row ] }
    asked = rows.select { |cv, _| cv.askable_to_patient? }
    unasked = rows.reject { |cv, _| cv.askable_to_patient? }
    specific_asked = asked.count { |cv, _| cv.specific? }
    routes = Rails.application.routes.url_helpers
    url = ->(path) { "#{host}#{path}" }
    line = ->(*cols) { format("     %-3s %-9s %-62s %-8s %s", *cols) }

    out = [ "", "== Escenario del cuestionario ==" ]
    out << "Estudio ##{study.id}  «#{study.public_title}»  — #{study.patients.count} pacientes" \
           "#{built[:wiped].positive? ? " (#{built[:wiped]} borrados con RESET)" : ''}"
    out << ""
    out << "  1. Formulario público:  #{url.(routes.new_participation_request_path(study))}"
    out << "     (marca la autorización de datos y «soy mayor de edad»; el nombre es opcional)"
    page1 = asked.select { |cv, _| cv.basic? }
    page2 = asked.reject { |cv, _| cv.basic? }
    out << "  2. Te lleva al cuestionario, en DOS páginas:"
    [ [ "Página 1 — básicas (más ciudad, archivos y autorización a futuro)", page1 ],
      [ "Página 2 — específicas (solo si la página 1 encaja)", page2 ] ].each do |title, questions|
      out << ""
      out << "     #{title}:"
      out << line.("#", "nivel", "pregunta", "PASA", "FALLA")
      questions.each_with_index do |(cv, row), i|
        out << line.(i + 1, cv.criteria_category, cv.patient_prompt.truncate(62), shown(row[8]), shown(row[9]))
      end
    end
    out << ""
    out << "     En ninguna deben aparecer (específicos sin pregunta; solo los mide el centro):"
    unasked.each { |cv, _| out << "       · #{cv.name}" }
    out << "     El recuadro amarillo de la página 1 lista solo las 3 exclusiones BÁSICAS."
    out << ""
    out << "  Qué esperar:"
    out << "     a) las 5 básicas en PASA            → «Continuar» lleva a la página 2 (ya está en Candidato);"
    out << "                                           al enviarla → «El centro revisará tus respuestas…»"
    out << "     b) una básica en FALLA (p. ej. 3=Sí) → termina en la página 1: «…no parece corresponder…»; Interesado"
    out << "     c) una básica en blanco o «No sé»    → igual que (b), mismo mensaje, a propósito"
    out << "     Volver atrás desde la página 2 lleva a la página 2: la página 1 no se responde dos veces."
    out << "     Las específicas no cambian el estado en ningún caso: quedan como testimonio."
    out << "     En la lista del rep se ven como «N/#{specific_asked + unasked.size} declarados» " \
           "(máximo #{specific_asked}: las otras #{unasked.size} no se preguntan)."
    out << ""
    out << "  3. Lado del centro: entra como #{REP_EMAIL} / #{PASSWORD}"
    out << "     #{url.(routes.patients_path)}  → el paciente aparece en «Candidato» con su chip de declarados"
    out << "     Abre el paciente → «Abrir evaluación»: debajo de cada criterio respondido sale «Paciente declaró: …»."
    out << "     Para llevarlo a Potencial hay que REGISTRAR los #{rows.size} valores (columna PASA de arriba, más:)"
    unasked.each { |cv, row| out << format("       %-48s PASA %-6s FALLA %s", cv.name, shown(row[8]), shown(row[9])) }
    out << "     Guardar NO lo promueve (la automatización se detiene en Candidato); el botón «Aceptar» sí se habilita."
    out << "     Con el paciente en Potencial, registrar un específico en FALLA lo devuelve solo a Candidato."
    out << ""
    out << "  Ejemplos ya creados (#{built[:seeded]} nuevos en esta corrida). En «Candidato» el orden debe ser Dani, Ana, Hugo:"
    EXAMPLES.each do |spec|
      patient = Patient.find_by(participant_code: spec[:code])
      now = patient ? state_label(patient.state) : "—"
      drift = patient && patient.state != spec[:expected] ? "  ⚠ esperado #{state_label(spec[:expected])}" : ""
      name = patient&.display_name || spec[:code]
      out << format("     %-24s %-11s %s%s", name, now, spec[:story], drift)
    end
    out << ""
    out << "  Admin: #{User.admins.first&.email} / #{PASSWORD} (contraseña de los seeds)"
    out << "  Repetir desde cero: RESET=1 bin/rails scenarios:self_report (borra TODOS sus pacientes, también los creados a mano)"
    out << ""
    out.join("\n")
  end
end
