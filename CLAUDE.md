# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Medici App is a Rails 8 healthcare application that connects patients with clinical trials in Colombia. It manages sponsors, trial center facilities/branches, studies, eligibility criteria, and patient enrollment/tracking through a trial's lifecycle.

## Development Commands

```bash
# Start development server
rails server

# Rails console
rails console

# Database
rails db:setup
rails db:migrate
rails db:seed

# Run all specs (RSpec)
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/models/patient_spec.rb

# Run a single example by line number
bundle exec rspec spec/models/patient_spec.rb:20
```

## Linting & Security

```bash
bin/rubocop                  # Ruby linting (rubocop-rails-omakase)
bin/rubocop -a               # Auto-fix offenses
bin/brakeman --no-pager      # Security scan
bin/importmap audit          # JS dependency audit
```

CI (`.github/workflows/ci.yml`) runs Brakeman, importmap audit, and RuboCop on every PR and push to `main`. **It does not run the RSpec suite** — tests are not currently enforced in CI.

## Testing

- Framework: RSpec (`spec/models`, `spec/requests`, `spec/routing`, `spec/views`, `spec/helpers`, `spec/factories`).
- No Capybara/Selenium — there are no browser-driven feature specs in this project (unlike other projects in this workspace). Flows are covered via request specs, not full-browser UI specs.
- `shoulda-matchers` is configured in `spec/rails_helper.rb` for concise model/association assertions.
- Data built with FactoryBot (`spec/factories/`) + Faker.

## Architecture

### Authentication & Authorization

- **Devise** handles authentication on `User`, with custom `users/registrations` and `users/sessions` controllers (`app/controllers/users/`).
- **Patient registration is study-scoped — this is intentional, not a bug.** There is no standalone public sign-up: a bare `GET /users/sign_up` returns **404 by design**. A patient signs up by first picking a **Study** to participate in; that puts a `study_id` in the session (`configure_permitted_parameters` permits `:study_id` on `:sign_up`), and `Users::RegistrationsController#create` then creates the `User` + `Patient` (`userable`) tied to that study. So the entry point is a study/participation link, never a generic registration page. Do not "fix" the 404 or add a standalone sign-up flow without understanding this — patient creation is deliberately coupled to study selection.
- **Pundit** handles authorization (`app/policies/`). `ApplicationController` includes `Pundit::Authorization`. Only a few policies exist so far (`patient_policy.rb`, `study_policy.rb`, `static_page_policy.rb`) — most controllers do not yet enforce a policy.
- `SecureApplicationController < ApplicationController` adds `before_action :authenticate_user!`; controllers that require login inherit from it instead of `ApplicationController` directly.
- `PaperTrail` is included in the Gemfile for auditing/versioning (check individual models for `has_paper_trail` before assuming a model is versioned).

### User / Role Model (delegated_type, not enum or STI)

`User` is the Devise-authenticatable identity, but role-specific data lives on separate models via Rails' `delegated_type`:

```ruby
delegated_type :userable, types: %w[SponsorRep Admin Patient TrialCenterBranchRep], dependent: :destroy
```

- **Patient**, **Admin**, **SponsorRep**, **TrialCenterBranchRep** each `include Userable` (`app/models/concerns/userable.rb` — actually `app/models/userable.rb`), which gives them `has_one :user, as: :userable` plus delegated `firstname`/`lastname`/`email`/`fullname`.
- `User` delegates domain attributes (`dob`, `sex`, `contact_number`, `state`, etc.) back down to whichever `userable` it wraps.
- Role checks are plain predicate methods on `User` (`user.patient?`, `user.sponsor?`, `user.admin?`, `user.trial_center_branch_rep?`) backed by `userable_type`, not an enum column — **do not add a `role` enum**, extend the existing delegated-type pattern instead.
- Scopes exist for querying by role: `User.patients`, `User.sponsors`, `User.admins`, `User.trial_center_branch_reps`.

### Patient Lifecycle (AASM state machine)

`Patient` uses **AASM** (not a plain enum) to track trial participation status:

```
prospect --assess--> candidate --accept--> participant
candidate --discard--> prospect
participant --reject--> candidate
```

State lives in the `state` column. Use `patient.assess!` / `patient.accept!` / `patient.discard!` / `patient.reject!` (or the non-bang predicate forms) rather than writing to `state` directly, so callbacks/guards stay intact if added later.

### Core Domain Model

- **Sponsor** — funds/owns a **Study**; has `sponsor_type` enum (`private_type` / `public_type` / `mixed_type`) and many `SponsorRep`s.
- **Study** — belongs to a Sponsor; has `study_status` (`completed` / `recruiting`) and `study_phase` (`I`–`IV`) enums; joined to `TrialCenterBranch`, `User` (participants), and `Medication` via HABTM; has one `CriteriaProfile`; has many `Article`, `Result`, `TrialCity`, `Contact`.
- **TrialCenterFacility → TrialCenterBranch** — a facility has many branches; branches join Studies and Cities (HABTM) and have `TrialCenterBranchRep`s.
- **CriteriaProfile → CriteriaVariable** — eligibility criteria attached to a Study (or reusable, since `study` is optional). Each `CriteriaVariable` has `value_type` (boolean/quantitative/qualitative), `variable_type` (inclusion/exclusion), and `comparison_type` (less_than, more_than, between_range, equal, etc.) enums — this is a small rules-engine for trial eligibility, not free-text criteria.
- **Result** — belongs to Study, `result_type` enum (Primary/Secondary).
- Geography: **Country → City / TrialCity**, referenced by facilities, branches, and studies.

### Eligibility criteria engine (analyzed 2026-07-13)

How the inclusion/exclusion rules engine is modeled — three tables, `app/models/{criteria_profile,criteria_variable,variable_value}.rb`:

- **`CriteriaProfile`** — a named, reusable set of eligibility rules. `belongs_to :study` (optional → reusable across studies) and `belongs_to :user` (owner); `has_many :criteria_variables`.
- **`CriteriaVariable`** — ONE atomic rule. Its "grammar": `name` + `value_type` (the datatype: `boolean` / `quantitative` / `qualitative`) + `variable_type` (the polarity: `inclusion` = patient must satisfy / `exclusion` = patient must NOT satisfy) + `comparison_type` (the operator: `less_than`, `less_than_or_equal`, `more_than`, `more_than_or_equal`, `between_range`, `out_of_range`, `equal`, `different`, `true`, `false`) + operands: `reference_value_1`/`reference_value_2` (decimals; two are used for `between_range`/`out_of_range`), or `qualitative_scale` (array of allowed categories) + `qualitative_value` (the category to compare against). Plus `criteria_order`, `enabled`, `shown`, free-text `conditions`.
- **`VariableValue`** — same column shape as `CriteriaVariable` but `belongs_to :patient` and adds `value` (the patient's actual measured value). It is the per-patient snapshot meant to be checked against a profile's variables (`Patient has_many :variable_values`).

**Key limitations (important — the engine is a rule *representation*, not yet an evaluator):**
- **No evaluation/matching code exists.** Nothing compares a patient's `VariableValue.value` against a `CriteriaVariable`'s `comparison_type` + reference values to decide eligibility. "All inclusion pass AND no exclusion triggers" is implied but unimplemented. So today it stores criteria and patient values; it does not compute eligibility.
- **Atomic only — no boolean composition.** Each variable is a single comparison. There is no AND/OR/grouping/nesting, so a compound rule ("severe = score ≥ 20 AND BSA ≥ 10%") must be split into several separate variables, and an OR ("candidate due to A *or* B") cannot be represented — only flattened to one boolean.
- **No temporal semantics.** "in the last 2 / 6 / 24 weeks" is descriptive text baked into the variable `name`; the engine compares a static value, never a date window.
- **No investigator-judgment / free-text criteria** as first-class — clinical catch-alls ("any condition that, in the investigator's opinion, …") can only be modeled as a single boolean flag the investigator toggles.

### JavaScript

Import maps (no JS build step). Hotwire (Turbo + Stimulus) is available via the Gemfile, but check `app/javascript/controllers/` before assuming a given page is Stimulus-driven — usage is lighter than a fully Hotwire-native app.

### Styling

Bootstrap 5 (`bootstrap` gem) + `dartsass-rails`. Custom healthcare color palette overrides Bootstrap variables — documented in `docs/color_palette.md`. Reusable custom classes: `.health-card`, `.stat-card`. Follow the existing palette/contrast guidance in that doc rather than introducing new ad hoc colors.

### Pagination

`will_paginate` + `bootstrap-will_paginate`. `RECORDS_PER_PAGE = 12` is defined in `ApplicationController`.

### Database

PostgreSQL, single database (no Solid Cache/Queue/Cable multi-db split as in other projects in this workspace — verify `config/database.yml` before assuming otherwise if the Gemfile changes).

### Deployment

Kamal (Docker-based). Config in `.kamal/`.

## Key Conventions

- Prefer extending the `delegated_type`/`Userable` pattern for new role-specific data rather than adding columns to `User` directly.
- Prefer AASM events over direct state-column writes for `Patient` status changes.
- Model files carry Rails schema-annotation comments (`# == Schema Information`) at the top — keep them in sync (the `annotate` gem manages these; don't hand-edit stale ones, just re-run annotate).
- `RSpec` is the only test framework — no Minitest.

## Research Notes

Findings investigated collaboratively with Claude (regulatory, domain, or technical) that apply to this project get logged here, independently from the `hdc` project's own notes.

**Related docs (not auto-loaded — read these for full context before continuing this work):**
- [`docs/investigacion_datos_pacientes_colombia.md`](docs/investigacion_datos_pacientes_colombia.md) — full research writeup in Spanish, with the complete source registry (every ley/resolución/circular consulted, confirmed vs. refuted claims), for detailed human review.
- [`docs/informe_socios_cumplimiento_datos_pacientes.md`](docs/informe_socios_cumplimiento_datos_pacientes.md) — non-technical partner-facing summary in Spanish.
- [`docs/sources/`](docs/sources/) — permanent local copies of the actual laws/resoluciones/decretos consulted (PDF/HTML, downloaded 2026-07-11), in case a government link changes or goes down. See `docs/sources/README.md` for the source-to-file mapping.

**Task status protocol:** the checklist under "Critical pending tasks" below is the single source of truth for remediation progress. When a task is completed, check it off (`- [x]`) and add a one-line note with the date — don't leave completed work undocumented, and don't start a task marked done without first verifying it's actually still true in the code.

### Colombian patient data regulation (researched 2026-07-11)

medici_app collects and stores identifiable, health-related patient data (`Patient` fields: `dob`, `sex`, `contact_number`, `notes`, `illness_description`; `CriteriaVariable`-based eligibility data) as part of clinical trial enrollment. This is subject to Colombia's general data-protection law (Ley 1581 de 2012) and, because it's a clinical-trials context specifically, potentially INVIMA-specific rules not yet confirmed (see gaps below). Findings were adversarially verified against primary sources (funcionpublica.gov.co, minsalud.gov.co); confidence and gaps are flagged explicitly — do not treat unconfirmed items as fact.

**Legal basis for processing (high confidence):**
- Health-related data is legally "dato sensible" (Ley 1581 de 2012, Art. 5 — not Decreto 1377/2013, which is only the implementing decree).
- Processing sensitive data is prohibited by default; requires explicit, prior, informed authorization from the patient (Art. 6, 9), with a carve-out for medical/health emergencies (Art. 10). Action: verify the Devise `users/registrations` sign-up flow captures explicit authorization for processing sensitive health data as a discrete, auditable step — not folded into a generic terms-of-service checkbox, and captured *before* a `Patient` record starts collecting `dob`/`sex`/`illness_description`/etc.
- Enforcement authority is the Superintendencia de Industria y Comercio (SIC): fines up to 2,000 SMLMV, processing suspension up to 6 months, or definitive closure for sensitive-data violations.

**Restricted access principle (applies by analogy from Resolución 1995 de 1999, Art. 14 — MinSalud's clinical-record access rule):** clinical-record access is legally limited to the patient, the treating/study team, judicial/health authorities per law, and others determined by law. Even though medici_app isn't a hospital EHR, `Patient.illness_description`, `dob`, `sex`, `notes`, and criteria-eligibility data are clinical data about an identifiable person and should be gated the same way. Action: `app/policies/patient_policy.rb` is the natural enforcement point — verify it actually restricts visibility of these specific sensitive fields per role (`SponsorRep` vs `TrialCenterBranchRep` vs `Admin`), not just record-level CRUD permissions. Most controllers currently have no Pundit policy at all (per the Architecture section above) — this is a gap.

**Technical/security baseline (by analogy from Resolución 1995 de 1999, Art. 16, 18):** immutability of finalized clinical/eligibility entries, access restricted to authorized personnel, and per-entry user+timestamp audit attribution. medici_app already has the `paper_trail` gem in the Gemfile — action: confirm `has_paper_trail` is actually declared on `Patient`, `CriteriaVariable`, and any other model holding clinical/eligibility data (not yet verified to be applied — see Architecture section).

**Explicitly NOT confirmed for this research pass — flagged as open gaps, not answered:**
- **INVIMA clinical-trial-specific regulation** (e.g. informed consent documentation format for trial participants, Resolución 2378 de 2008 or successor rules) — this is core to medici_app's function and was NOT resolved by this research pass. Needs a dedicated follow-up before treating the current enrollment/consent flow as compliant.
- Retention period for patient/trial data: a commonly cited "5+15 years" figure (tied to Resolución 839 de 2017, which amends MinSalud's Resolución 1995 de 1999) was specifically checked and refuted by adversarial verification. Do not hardcode retention/deletion logic on that number.
- Whether medici_app falls under the mandatory national interoperability regime (Ley 2015 de 2020 + Resolución 866 de 2021 + Resolución 1888 de 2025, jointly MinSalud + MinTIC — compliance deadline ~April 15, 2026, already past as of today 2026-07-11) is unclear: medici_app doesn't generate primary clinical encounter/hospitalization/consultation records itself, but it does hold clinical eligibility data tied to patients participating in studies at trial center branches that likely are obligated actors. Treat as an open question requiring follow-up, not as out-of-scope by default.
- Exact breach-notification obligation (timing, authority) for a health-data security incident — not covered by this research pass.

**Cross-border transfer (relevant to Sponsors):** Ley 1581 de 2012 Art. 26 prohibits transferring personal data to countries without "adequate" protection (per SIC) by default, with exceptions for explicit consent, health-treatment-related exchange, treaty, or contract necessity. Since `Sponsor`s in this domain model may be international pharmaceutical companies, any data flow of patient enrollment/eligibility data to a foreign sponsor needs an explicit legal-basis check — don't assume the contract-necessity exception covers it without review.

Sources: [Ley 1581 de 2012](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981), [Resolución 1995 de 1999](https://www.minsalud.gov.co/normatividad_nuevo/Resoluci%C3%B3n%201995%20de%201999.pdf), [Resolución 866 de 2021](https://www.minsalud.gov.co/Normatividad_Nuevo/Resoluci%C3%B3n%20No.%20866%20de%202021.pdf), [Resolución 1888 de 2025](https://www.minsalud.gov.co/Normatividad_Nuevo/Resolucion%20No%201888%20de%202025.pdf).

### Colombian interoperability scope & INVIMA clinical-trial regulation (researched 2026-07-11, verified)

**Interoperability scope (Resolución 866 de 2021 Art. 2):** same closed, 9-category list documented in `hdc`'s CLAUDE.md — clinical trial sponsors, CROs, and trial sites are never named anywhere in the resolution's text (zero occurrences of "ensayo clínico", "investigación clínica", "patrocinador", "CRO" in a full-text search). Unlike a diagnostic lab, there's no plausible catch-all category for trial organizations either — they don't naturally fit "prestadores de servicios de salud" (not typically licensed healthcare providers) nor any of the other 8 categories (EPS, insurers, territorial health authorities, etc.). **Conclusion (medium confidence — inference from absence, not an explicit exclusion):** the stronger reading is that clinical-trial organizations, as such, fall **outside** the IHCE/RDA interoperability mandate — but this is inferred from silence, not stated in the regulation. Flag it as such in any compliance documentation rather than treating it as a confirmed exemption.

**INVIMA clinical trial regulation (high confidence, primary source: INVIMA's Anexo Técnico to Resolución 2378 de 2008):**
- Governing regulation remains **Resolución 2378 de 2008** (issued by the *Ministerio de la Protección Social* — not INVIMA directly; INVIMA is the certifying/administering authority), mandatorily adopting Good Clinical Practice (Buenas Prácticas Clínicas) for institutions conducting human drug research in Colombia. No successor/amending resolution was found through 2025/2026 (a 2025 legal bulletin flags it as "due for modernization" but still currently in force).
- **Informed consent — concrete, actionable requirement:** the consent form must be signed and dated by (a) the participant (or legal representative/guardian for vulnerable populations), (b) **two witnesses**, and (c) the investigating physician ("médico investigador") — a wet-ink, multi-party signature requirement materially stricter than a single Ley 1581 habeas-data authorization. This is an audited checklist item (item 32 of INVIMA's institutional evaluation instrument) and the form must be re-signed/re-dated whenever amended. **Action:** medici_app's current enrollment flow (Devise sign-up → `Patient` AASM `prospect` state) has no documented multi-party consent capture — this is a compliance gap to close, not something a Ley 1581 authorization checkbox alone satisfies.
- **Participant sample/data handling (Tabla 7 of the Anexo Técnico):** requires a pseudonymization/coding system — participant identity must be linkable to research data only via codes, with records stored in a secure location accessible only to the study-responsible person. **Action:** verify `CriteriaVariable`/eligibility data in medici_app is coded/pseudonymized where it feeds into trial reporting, not just access-controlled via Pundit roles.
- **Explicitly NOT confirmed — flagged as open gaps, do not assume:**
  - How INVIMA consent legally interacts with Ley 1581 habeas-data authorization (whether one satisfies the other, or both are independently required) — no primary source found addressing this relationship. Treat as **layered/additional requirements** (the safer assumption, given INVIMA's requirements are structurally distinct and stricter) rather than substitutes, pending confirmation.
  - Electronic/digital informed consent permissibility — not addressed in sources reviewed.
  - Sponsor access rules to identifiable participant data, and data monitoring committee (DSMB) access — not addressed.
  - Cross-border transfer of participant data to international sponsors under INVIMA's regime specifically (distinct from the general Ley 1581 Art. 26 framework already documented above) — not addressed.
- **Correction to a previously-logged preliminary note:** an earlier hypothesis that informed-consent requirements trace to Resolución 8430 de 1993 rather than Resolución 2378 de 2008 did **not** survive adversarial verification (1-2 vote, not confirmed). Resolución 2378 de 2008's own Anexo Técnico is the confirmed, direct source of the consent requirements above — do not cite Resolución 8430 de 1993 for trial-specific informed consent without further dedicated verification.

Sources: [Resolución 2378 de 2008 (INVIMA)](https://mesagil.invima.gov.co/biblioteca/resolucion_20no_202378_20de_202008_1pdf), [INVIMA BPC certification page](https://www.invima.gov.co/productos-vigilados/medicamentos-y-productos-biologicos/medicamentos-de-sintesis-quimica-y-biologica/licenciamiento-auditorias-y-certificaciones/certificaciones-en-buenas-practicas), [Resolución 866 de 2021 (primary PDF)](https://www.minsalud.gov.co/sites/rid/Lists/BibliotecaDigital/RIDE/DE/DIJ/resolucion-866-de-2021.pdf).

### Compliance status vs. actual code (audited 2026-07-11)

Checked the requirements above against the current medici_app codebase directly (not inferred). Results — every item below is a confirmed gap, not a hypothesis:

- **Ley 1581 authorization capture at registration — NOT implemented.** `Users::RegistrationsController#create` ([app/controllers/users/registrations_controller.rb](app/controllers/users/registrations_controller.rb)) only handles the Devise sign-up plus auto-creating a `Patient`/`userable` tied to a `Study` when `study_id` is present in session. No consent/authorization field, checkbox, or step exists anywhere in the flow.
- **INVIMA informed consent (participant + 2 witnesses + investigating physician) — NOT implemented at all.** A repo-wide search for `consent`, `consentimiento`, `witness`, `testigo` returns zero results. No model, field, or view for this exists.
- **Participant data pseudonymization/coding (Anexo Técnico Tabla 7) — NOT implemented.** No coding/pseudonymization logic exists for `Patient` or `CriteriaVariable` data.
- **Audit trail — NOT implemented, despite the gem being present.** `paper_trail` is in the Gemfile but **`has_paper_trail` is declared on zero models** — confirms and closes out the earlier "not yet verified" flag as a confirmed gap.
- **Restricted access to sensitive clinical data — the most significant finding: NOT enforced for most actions.** In `app/controllers/patients_controller.rb`, Pundit's `authorize @patient, :update_state?` is called **only when the `state` param is present** (lines 38-42). The `index` action (`Patient.all`, unscoped), `show`, `edit`, `create`, and non-state `update` have **zero Pundit authorization**. Concrete consequence: **any authenticated user, regardless of role** (`SponsorRep`, `TrialCenterBranchRep`, `Admin`, or even another `Patient`), can list and view every patient's `dob`, `sex`, `illness_description`, and `notes`.
- **`StudyPolicy` is dead code.** It defaults every action (`index?`, `show?`, `create?`, `update?`, `destroy?`) to `false` with no overrides, but `app/controllers/studies_controller.rb` never calls `authorize` or `policy_scope` — the policy is never actually invoked.

**Priority for remediation:** the `PatientsController` access-control gap is the most urgent — it's a live, exploitable exposure of sensitive health data to any logged-in user, not just a future compliance-deadline risk like the interoperability question.

### Offshore hosting (Heroku/AWS) & "sponsors are just records" (researched 2026-07-13, web-sourced)

**Question raised:** medici_app is deployed on Heroku, which runs on AWS with servers in the US, so *all* patient data physically lives outside Colombia. Does that mean every patient must give an international-transfer authorization? (Adversarially checked against Colombian secondary legal sources; this is informational, **not legal advice** — the clinical-trials/INVIMA layer may be stricter, and the SIC adequacy list can change.)

**Finding — the key distinction is *transmisión* vs *transferencia* (Decreto 1377 de 2013, Art. 24–26):**
- **Transferencia** = sending data to another **responsable** (controller) that processes it for **its own** purposes → gated by Ley 1581 **Art. 26**: allowed only to an adequate-protection country **or** with explicit consent (or another exception).
- **Transmisión** = sending data to an **encargado** (processor) that processes **on the controller's behalf, under its instructions** → **does NOT require the titular's consent** when a data-processing/transmission **contract** exists (Art. 25). Foreign cloud hosting (Heroku/AWS) is a **transmisión**.
- **So offshore hosting does NOT require a per-patient transfer opt-in.** What it requires is: (a) a **Data Processing / International Transmission Agreement (DPA)** with the provider (Salesforce/Heroku, AWS — both publish standard DPAs), and (b) the general Ley 1581 authorization to **acknowledge** that data may be processed by operators possibly located abroad. Security baseline: SIC recommends ISO/IEC 27001.
- **Bonus:** the **US is on the SIC's adequate-protection list** (Circular Externa 005 de 2017, ~37 jurisdictions — controversially, but it is listed), so even a US *transferencia* would satisfy Art. 26's adequacy exception.

**Domain correction (2026-07-13):** in medici_app, **`Sponsor` records are just labels to organize studies — the app does not actually transmit patient data to sponsors.** The only legally-bound data subject is the **`Patient`**. Therefore the "transferencia to a foreign sponsor" scenario (task 7's original premise) is **not a real data flow here**; the real offshore flow is the **hosting transmisión**, which every patient's data is subject to. The `sponsors.international` flag + sponsor cross-border consent built for task 7 are harmless but **precautionary, not a legally-triggered requirement** given sponsors aren't recipients.

**What medici_app actually needs (net of the above):**
1. **[dev — done 2026-07-13]** The base Ley 1581 authorization text acknowledges processing by third-party operators possibly abroad under a transmission contract (added to the sign-up consent).
2. **[legal/process — not code]** Execute DPAs with Heroku/Salesforce and AWS; confirm ISO 27001 posture. Confirm who is "responsable" (likely the trial site/sponsor entity, not the software vendor).
3. The sponsor cross-border-consent code stays as a dormant safeguard; do **not** treat it as the mechanism that legitimizes offshore hosting — that's the DPA + base-consent acknowledgment.

Sources: [Ley 1581 de 2012](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=49981), [Decreto 1377 de 2013](https://www.funcionpublica.gov.co/eva/gestornormativo/norma.php?i=53646), [Ámbito Jurídico – régimen de transferencias](https://www.ambitojuridico.com/noticias/comercial/regimen-de-transferencias-internacionales-de-datos-personales-una-guia-rapida), [Cuadro Legal – nube (2025)](https://cuadrolegal.com/2025/11/05/habeas-data-y-servicios-de-computacion-en-la-nube/), [SIC Circular Externa 005 de 2017](https://normograma.dian.gov.co/dian/compilacion/docs/circular_superindustria_0005_2017.htm).

### Critical pending tasks — compliance remediation (planned 2026-07-11)

Each item below is a task to execute, not just a gem to install — most gaps need real development work, with a gem (if any) as only one ingredient. Ordered by priority. **Status as of 2026-07-13: 6/8 done (tasks 1, 2, 3, 5, 6, 7).** Remaining: 4 (INVIMA multi-party consent — dev, blocked on legal task 8) and 8 (legal, not dev). Check items off as they're completed, with a one-line dated note.

- [x] 1. **[CRITICAL — live exposure] Fix the Pundit access-control gap in `PatientsController`.** _(2026-07-13 — PR #28, role permissions.)_
   - Gem: none new — `pundit` is already in the Gemfile. This is a wiring task.
   - Dev work: extend `PatientPolicy` with real `index?`/`show?`/`update?` rules (not just the existing `update_state?`/AASM-transition methods, scoped by role); call `authorize`/`policy_scope` in `PatientsController#index`, `#show`, `#edit`, `#create`, and non-state `#update`. This is the highest-priority fix — it's a live exposure of every patient's `dob`/`sex`/`illness_description`/`notes` to any logged-in user today, not a future deadline risk.
   - **Done:** `PatientsController < SecureApplicationController`, whose `ResourceAuthorization` concern auto-authorizes every standard action and whose `verify_authorized` after_action makes a missed `authorize` a failing spec (deny-by-default). The unscoped `index`/`show` exposure is closed.

- [x] 2. **[HIGH] Fix or remove the dead `StudyPolicy`.** _(2026-07-13 — PR #28, role permissions.)_
   - Gem: none new — `pundit` already present.
   - Dev work: either wire `authorize`/`policy_scope` into `StudiesController` so `StudyPolicy` actually runs, or remove it if intentionally unused — a policy file that looks like it's enforcing access but isn't is worse than no policy at all.
   - **Done:** `StudiesController < SecureApplicationController` now authorizes (standard actions via `ResourceAuthorization`, plus an explicit `authorize(@study, :update?)` for its custom action); `StudyPolicy < ApplicationPolicy` inherits the real permission-driven rules — no longer dead code.

- [x] 3. **[CRITICAL] Implement Ley 1581 authorization capture at registration.** _(2026-07-13 — branch `MA-pseudonymization`.)_
   - Gem: none — no standard gem exists for Colombian habeas-data consent capture.
   - Dev work: add a `Consent`/`Authorization` model (who authorized, what text/version, when) and a discrete, auditable step in the sign-up flow (`Users::RegistrationsController`) that captures it **before** `dob`/`sex`/`illness_description`/etc. start being collected — not folded into a generic terms-of-service checkbox.
   - **Done:** `Consent` model (immutable, versioned: document_type/version, purpose, granted_at, ip_address; `has_paper_trail`). A distinct habeas-data authorization checkbox on the study-scoped sign-up form; registration is a hard gate (no account/data without it — rejected sign-up 422s and creates nothing); a `Consent` is persisted on success. Version bumps via `Consent::LEY_1581_CURRENT_VERSION`. Also fixed a latent "Userable must exist" registration bug (Patient is now built before the User is saved).

- [ ] 4. **[CRITICAL] Implement INVIMA multi-party informed consent (participant + 2 witnesses + investigating physician).**
   - Gem options: `prawn` (add to Gemfile) to generate the consent PDF, + Active Storage (already in Rails, no separate gem) to attach the signed document; `hexapdf` (evaluate, don't add yet) if a digital-signature path is chosen instead of scanned wet-ink signatures.
   - Dev work: build the consent capture flow (participant/legal representative + 2 witnesses + investigating physician), require re-signature when the form is amended, and track it as an auditable checklist item equivalent to INVIMA's item 32.
   - **Blocked on:** legal confirmation of whether a pure digital signature satisfies Resolución 2378 de 2008, or whether a scanned wet-ink signature is required — don't commit to the `hexapdf` path before this is confirmed.

- [x] 5. **[HIGH] Implement participant data pseudonymization/coding (Anexo Técnico Tabla 7).** _(2026-07-13 — branch `MA-pseudonymization`.)_
   - Gem: none new — use Rails 8's native `ActiveRecord::Encryption`.
   - Dev work: encrypt identifiable clinical fields (`illness_description`, `dob`, etc.) that feed into study/eligibility data, and add a participant-code column (`SecureRandom`-backed) so research data can be linked to identity only via that code, per the secure-storage requirement.
   - **Done:** `Patient` now owns its identity (delegation moved off the shared `User` into `DelegatesIdentityToUser`, used only by Admin/reps) and encrypts `firstname`/`lastname`/`email`/`dob`/`contact_number`/`contact_address`/`id_number` (deterministic, searchable) + `illness_description`/`notes` (non-deterministic). `dob` moved date→string (+ `attribute :dob, :date`). Added `participant_code` (unique, `SecureRandom`, backfilled). `has_paper_trail skip:` the encrypted fields so plaintext never reaches the `versions` table. Keys via `config/initializers/active_record_encryption.rb` (ENV in prod). **Post-deploy:** set `AR_ENCRYPTION_*` env vars on Heroku, then run `rails patients:reencrypt` to encrypt existing rows. Devise login (`User#email`) is untouched. Status: 4/8 done (1, 2, 5, 6).

- [x] 6. **[HIGH] Wire the audit trail.** _(2026-07-13 — branch `MA-variable-value-attribution`.)_
   - Gem: none new — `paper_trail` is already in the Gemfile.
   - Dev work: declare `has_paper_trail` on `Patient`, `CriteriaVariable`, `Study`, and any other model holding clinical/eligibility data.
   - **Done:** installed PaperTrail (`versions` table), wired `set_paper_trail_whodunnit` in `ApplicationController` (PaperTrail 15 no longer auto-installs it) so every change records the acting user, and declared `has_paper_trail` on `Patient`, `VariableValue`, `CriteriaVariable`, `CriteriaProfile`, and `Study`. Also added an `entered_by` user FK on `VariableValue` (first-capture attribution).

- [x] 7. **[MEDIUM] Add a cross-border transfer safeguard for international `Sponsor`s.** _(2026-07-13 — branch `MA-pseudonymization`.)_
   - Gem: none — this is a process/legal control (data transfer agreements, explicit consent language), not a technical one.
   - Dev work: minimal — mostly ensure the Ley 1581 authorization captured in task 3 explicitly covers transfer to a foreign sponsor when applicable, and flag/log which `Sponsor`s are international.
   - **Done:** `sponsors.international` flag + `Study#international_sponsor?`. When enrolling in an international-sponsor study, the sign-up authorization shows an Art. 26 cross-border clause and a distinct `Consent` (`ley_1581_cross_border_transfer`) is recorded alongside the base one.
   - **Re-fit (2026-07-13, see "Offshore hosting" note above):** the real offshore data flow is **hosting on Heroku/AWS (US), which is a *transmisión* to a processor**, not a transferencia — handled by a **DPA (legal/process)** + a *transmisión* acknowledgment now in the **base** consent text (all patients), not by a per-patient opt-in. And **`Sponsor`s are only records** (no real data flow to them), so this sponsor cross-border consent is **precautionary, not legally triggered**. Remaining real item is **legal/process**: execute DPAs with Heroku/Salesforce + AWS and confirm the "responsable" is the trial site/sponsor entity.

- [ ] 8. **[MEDIUM — legal, not dev] Resolve the open INVIMA / Ley 1581 interaction questions.**
   - Not a development task: get legal confirmation on (a) whether INVIMA consent satisfies or stacks on top of Ley 1581 authorization, (b) electronic consent validity, (c) sponsor/DMC access rules to identifiable data.
   - Blocks the final design of tasks 3 and 4 — build the safer "both required" version now, revise once confirmed.
   - **Cross-border question RESOLVED (2026-07-13):** offshore hosting = *transmisión* (DPA, not per-patient consent); US is on the SIC adequacy list. Remaining legal items are the INVIMA consent questions (a/b/c above) + executing the hosting DPAs (a contract/process task, not code). See the "Offshore hosting" research note above.
