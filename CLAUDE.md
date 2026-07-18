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

CI (`.github/workflows/ci.yml`) runs four jobs on every PR and push to `main`: Brakeman, importmap audit, RuboCop, and **the full RSpec suite** (`test` job: Postgres service container, Chrome for the `js: true` feature specs, `dartsass:build` for CSS, and — critically — `yarn install`, because five importmap pins (trix, @rails/actiontext, @rails/activestorage, bootstrap, bootstrap-icons) are served out of `node_modules` via Propshaft asset paths; without them the browser's ES-module graph fails and every JS-driven feature spec breaks while the rest of the suite stays green (exactly the failure CI showed until 2026-07-18).

## Testing

- Framework: RSpec (`spec/models`, `spec/requests`, `spec/features`, `spec/routing`, `spec/views`, `spec/helpers`, `spec/jobs`, `spec/factories`).
- Capybara/Selenium feature specs exist in `spec/features/` (first added with the campaign module; the consent-gate specs are `js: true` and run headless Chrome). Most flows are still covered via request specs — feature specs are reserved for behavior that genuinely needs a browser (JS gating, Stimulus).
- `shoulda-matchers` is configured in `spec/rails_helper.rb` for concise model/association assertions.
- Data built with FactoryBot (`spec/factories/`) + Faker.

## Architecture

### Authentication & Authorization

- **Devise** handles authentication on `User`, with a custom `users/sessions` controller (`app/controllers/users/`).
- **Nobody self-registers. `User` is deliberately NOT `:registerable`** — the sign-up routes, `Users::RegistrationsController` and its views do not exist. Staff accounts (admins, sponsor reps, trial centre reps, platform staff) are created by an admin through the role-specific controllers. **Do not re-add `:registerable`** to "fix" a missing sign-up page; there isn't meant to be one.
- **Patients have NO accounts at all** (changed 2026-07-15 — an earlier version of this file described the opposite and told you not to change it; that guidance is obsolete). A patient is a plain record, never a `User`:
  - **Public route:** "¡Quiero participar!" → `ParticipationRequestsController` (`GET/POST /studies/:study_id/participate`, public, no login). It captures a **contact number and/or email** plus the study, and creates a `Patient` (AASM `prospect`) and a `Consent`. Nothing clinical is accepted here — the permitted params are only `:contact_number, :email`.
  - **Staff route:** a trial centre rep or admin builds the real clinical record via `PatientsController` (the full form).
  - **The Ley 1581 authorization is still a hard gate** on the public form: leaving a phone number against a *named clinical trial* says something about your health, so nothing at all is written until it is granted. See `ParticipationRequestsController#create`.
  - `Patient belongs_to :study` (`patients.study_id`) — **one study per patient**. This used to live on the patient's `User` via the `studies_users` HABTM; that join is now staff-only.
  - `Consent belongs_to :patient` (not `User` — there is no account to hang it on).
- **Pundit** handles authorization (`app/policies/`). `ApplicationController` includes `Pundit::Authorization`. Two distinct mechanisms, easy to confuse:
  - **`authorize`** answers *may this role touch this resource at all* — wired generically by the `ResourceAuthorization` concern, which authorizes the **model class, not the instance**. So overriding `show?`/`update?` to inspect `record` as an instance silently never fires for standard actions.
  - **`policy_scope`** answers *which rows* — this is where row-level rules belong. `PatientsController` loads **every** action through it (including member actions), so an out-of-reach patient **404s rather than 403s**: a 403 would confirm the record exists, which is itself a disclosure about an identifiable person.
- `SecureApplicationController < ApplicationController` adds `before_action :authenticate_user!`; controllers that require login inherit from it instead of `ApplicationController` directly.
- `PaperTrail` is included in the Gemfile for auditing/versioning (check individual models for `has_paper_trail` before assuming a model is versioned).

### User / Role Model (delegated_type, not enum or STI)

`User` is the Devise-authenticatable identity, but role-specific data lives on separate models via Rails' `delegated_type`:

```ruby
delegated_type :userable, types: %w[SponsorRep Admin Patient TrialCenterBranchRep PlatformStaff], dependent: :destroy
```

- **`Patient` is still listed as a type, but no patient User exists any more** (see above — patients have no accounts, and `RemovePatientUserAccounts` deleted the last ones on 2026-07-15). In practice `user.patient?` is always false and `User.patients` is always empty. The type is left in place so the delegated_type stays truthful about the column's history; **do not build new features on the assumption that a patient can log in**. Count patients with `Patient.count`, never `User.patients.count`.
- **Patient**, **Admin**, **SponsorRep**, **TrialCenterBranchRep**, **PlatformStaff** each `include Userable` (`app/models/concerns/userable.rb` — actually `app/models/userable.rb`), which gives them `has_one :user, as: :userable` plus delegated `firstname`/`lastname`/`email`/`fullname`.
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
- **Study** — belongs to a Sponsor; has `study_status` (`completed` / `recruiting`) and `study_phase` (`I`–`IV`) enums; joined to `TrialCenterBranch` and `Medication` via HABTM; **has many `Patient`s directly (`patients.study_id`)**; has one `CriteriaProfile`; has many `Article`, `Result`, `TrialCity`, `Contact`. It also still HABTMs `User`, but that join no longer carries patients — see the patient notes above.
- **Patient** — belongs to one **Study**. Reached from a centre via `Study ↔ TrialCenterBranch`: this chain (rep → branch → studies → patients) is what `PatientPolicy::Scope` walks, and `Patient.for_trial_center_branches` expresses.
- **TrialCenterFacility → TrialCenterBranch** — a facility has many branches; branches join Studies and Cities (HABTM) and have `TrialCenterBranchRep`s.
- **CriteriaProfile → CriteriaVariable** — eligibility criteria attached to a Study (or reusable, since `study` is optional). Each `CriteriaVariable` has `value_type` (boolean/quantitative/qualitative), `variable_type` (inclusion/exclusion), and `comparison_type` (less_than, more_than, between_range, equal, etc.) enums — this is a small rules-engine for trial eligibility, not free-text criteria.
- **Result** — belongs to Study, `result_type` enum (Primary/Secondary).
- Geography: **Country → City / TrialCity**, referenced by facilities, branches, and studies.

### Eligibility criteria engine (analyzed 2026-07-13; evaluator re-verified against the code 2026-07-15)

How the inclusion/exclusion rules engine is modeled — three tables, `app/models/{criteria_profile,criteria_variable,variable_value}.rb`:

- **`CriteriaProfile`** — a named, reusable set of eligibility rules. `belongs_to :study` (optional → reusable across studies) and `belongs_to :user` (owner); `has_many :criteria_variables`.
- **`CriteriaVariable`** — ONE atomic rule. Its "grammar": `name` + `value_type` (the datatype: `boolean` / `quantitative` / `qualitative`) + `variable_type` (the polarity: `inclusion` = patient must satisfy / `exclusion` = patient must NOT satisfy) + `comparison_type` (the operator: `less_than`, `less_than_or_equal`, `more_than`, `more_than_or_equal`, `between_range`, `out_of_range`, `equal`, `different`, `true`, `false`) + operands: `reference_value_1`/`reference_value_2` (decimals; two are used for `between_range`/`out_of_range`), or `qualitative_scale` (array of allowed categories) + `qualitative_value` (the category to compare against). Plus `criteria_order`, `enabled`, `shown`, free-text `conditions`.
- **`VariableValue`** — same column shape as `CriteriaVariable` but `belongs_to :patient` and adds `value` (the patient's actual measured value). It is the per-patient snapshot meant to be checked against a profile's variables (`Patient has_many :variable_values`).

**Evaluation — implemented (this section previously claimed it was not; corrected 2026-07-15 by reading the code):**
- **`CriteriaComparable`** (`app/models/concerns/criteria_comparable.rb`) — the atomic comparison, shared by `CriteriaVariable` (the rule) and `VariableValue` (the snapshot), since both carry the same comparison columns. `satisfied_by?(raw)` dispatches on `value_type` and implements every `comparison_type`. It is **polarity-agnostic** (knows nothing about inclusion/exclusion) and returns **`nil`** — not `false` — when the value is blank or unparseable, so callers can tell "unknown" from "fails". Also provides `rule_summary` (a short Spanish description, e.g. `"entre 18 y 40"`, `"≥ 20"`).
- **`CriteriaProfile#evaluate(patient)` → `EligibilityResult`** — the entry point. Considers only `enabled` variables, ordered by `criteria_order`. Applies polarity: `inclusion` passes when `met == true`, `exclusion` passes when `met == false`; an **unmeasured exclusion (`nil`) does not pass** and surfaces as incomplete rather than as a silent pass.
- **`EligibilityResult`** (`app/models/eligibility_result.rb`, a PORO — not an AR model) — wraps per-variable `Check` structs and answers two distinct questions: `eligible?` (every variable answered **and** passing) and `complete?` (nothing left to measure). Also `missing` and `failing`. Each `Check` reports `status` as `:pass` / `:fail` / `:missing`.
- **UI:** `CriteriaAssessmentsController` (`show`/`update`) at `/patients/:patient_id/criteria_assessment` captures a patient's values and renders the verdict. `update` upserts one `VariableValue` per variable, copying the rule onto the value (the snapshot design) and attributing the first capture via `entered_by`.

**Gotcha (FIXED 2026-07-16) — answers now match rules by FK, not by `name`.** Historically `evaluate` did `patient.variable_values.index_by(&:name)` and looked up `cv.name`, with no FK linking the two, so **renaming a `CriteriaVariable` silently orphaned every existing patient answer** (a patient reading `eligible=true, complete=true` flipped to `missing` the moment the rule was renamed). Fixed by adding `variable_values.criteria_variable_id` (FK, `on_delete: :nullify`), backfilled by name within the patient's profile. `CriteriaProfile#evaluate` and the assessment upsert now key off the FK, falling back to `name` only for legacy rows written before the FK existed; every capture refreshes the snapshot `name` to the rule's current name. Deleting a rule nullifies the FK but leaves the answer's snapshot intact as a historical record. Guarded by `spec/models/criteria_profile_spec.rb` ("keeps the answer linked when the rule is renamed"). Renaming is safe now — but a `VariableValue` still keeps its own snapshot columns by design, so treat those as a point-in-time copy, not a live mirror of the rule.

**Eligibility brief + promote (added 2026-07-16).** The assessment page (`CriteriaAssessmentsController#show`, `app/views/criteria_assessments/show.html.erb`) is now a decision brief: a verdict banner, at-a-glance stat cards (passing / out-of-reach / pending / answered-of-total), and dedicated **out-of-reach** (failing, with required-vs-measured) and **pending** (still-to-measure) cards so a rep or investigator sees exactly what blocks eligibility. From the brief they can promote the patient through the AASM lifecycle (the same policy-gated `PatientsController#transition` action), with the forward step highlighted when the patient is eligible. `EligibilityResult` gained `passing`/`pending`/`failing`/`verdict`/`answered_count`/`total_count` to back it.

**Key limitations (still true — the engine evaluates atomic rules only):**
- **Atomic only — no boolean composition.** Each variable is a single comparison, and `evaluate` implicitly ANDs them all. There is no AND/OR/grouping/nesting, so a compound rule ("severe = score ≥ 20 AND BSA ≥ 10%") must be split into several separate variables, and an OR ("candidate due to A *or* B") cannot be represented — only flattened to one boolean.
- **No temporal semantics.** "in the last 2 / 6 / 24 weeks" is descriptive text baked into the variable `name`; the engine compares a static value, never a date window.
- **No investigator-judgment / free-text criteria** as first-class — clinical catch-alls ("any condition that, in the investigator's opinion, …") can only be modeled as a single boolean flag the investigator toggles.

### Clinical notes (SOAP) & rich text / Action Text (added 2026-07-16)

`SoapNote` (`app/models/soap_note.rb`) is the standard **S**ubjective/**O**bjective/**A**ssessment/**P**lan clinical-encounter format (US healthcare; Weed's Problem-Oriented Medical Record). `Patient has_many :soap_notes` — a patient accumulates as many as the research produces. Each of the four sections is **Action Text rich text** (`has_rich_text`), and an `encounter_date` + `author` (the acting staff user) is stored on the row. Notes are audited (`has_paper_trail` on the metadata; whodunnit on every change).

- **Access mirrors `CriteriaAssessmentsController`, NOT the permission matrix.** `SoapNotesController` (nested `resources :soap_notes` under patients) gates on the *parent patient's* visibility: `set_patient` via `policy_scope(Patient).find` (out-of-reach patient 404s), then `authorize(@patient, :show?/:update?)`. `SoapNote` is deliberately **not** in `PermissionCatalog::RESOURCES`, so the controller overrides `authorization_model` to `nil` to opt out of `ResourceAuthorization`'s generic class-level authorize (which would otherwise deny all). Reps see/edit only their own centre's patients' notes; admins all; sponsor reps have no `Patient` permission and 404.
- **Action Text was installed 2026-07-16** (`action_text/engine` was required but not installed). Because this is a **Propshaft + importmap** app (no JS bundler), the pieces are wired the same node_modules way as bootstrap: `config/initializers/assets.rb` adds `node_modules/trix/dist` and `node_modules/@rails/actiontext/app/assets/javascripts` to the asset paths and precompiles `trix.esm.min.js`/`actiontext.esm.js`/`actiontext.css`; `config/importmap.rb` pins `trix` → `trix.esm.min.js` and `@rails/actiontext` → `actiontext.esm.js`; `application.js` imports both; the layout links `stylesheet_link_tag "actiontext"` (the sass-compiled `application.css` does not include Trix styles). **If you re-run any RSpec-touching Rails generator, it may force-overwrite `.rspec`/`spec/rails_helper.rb`** — the Action Text installer did; both were restored from git (they carry `pundit/rspec`, the support glob, and the Shoulda::Matchers config).
- **Images upload straight to S3, never the DB — by design.** `@rails/actiontext` registers a `trix-attachment-add` handler that runs an Active Storage **DirectUpload** the moment an image is dropped/pasted into a field; the rich-text body stores only the blob reference. Active Storage already uses the S3 service in production (`config.active_storage.service = :amazon`), so attachments land in the AWS bucket. `image_processing` was enabled in the Gemfile for variants. `@rails/activestorage` is also imported + `ActiveStorage.start()`ed in `application.js` so plain `file_field ..., direct_upload: true` inputs (outside Trix) upload direct-to-S3 too — used by ComplementaryInformation below.

### ComplementaryInformation & the patient treatment briefing (added 2026-07-16)

- **`ComplementaryInformation`** (`app/models/complementary_information.rb`, note the spelling — *complementary* = supplementary, not "complimentary") — one bundle per patient (`Patient has_one`). Holds a patient's prior-care exams: `has_many_attached :documents` (PDF only, validated), `has_many_attached :images` (image types, validated), and `has_rich_text :notes`. 25 MB/file cap. `ComplementaryInformationsController` is a **singular** nested resource (`show`/`edit`/`update` + a `purge_attachment` member DELETE) that builds the bundle lazily (`build_complementary_information` if none). `update` **appends** files via `.attach` rather than assigning the collection (Rails 7.1+ replaces on assign), so successive saves accumulate. Access is gated by the parent patient exactly like SOAP notes.
  - **Design note (open):** the goal framed this as something "the patient provides", but **patients have no accounts** (hard rule), so it is currently a **staff-managed** surface (rep/admin capture it on the patient's behalf). A patient-facing *public* upload page (tokenized, like the participation flow) was deliberately **not** built — an unauthenticated file-upload endpoint is an outward-facing security surface that needs an explicit product/security decision first.
- **`PatientBriefing`** (`PatientBriefingsController#show`, singular nested `resource :briefing`) — a read-only one-page treatment briefing for reps/admins that consolidates: lifecycle state + policy-gated promote buttons (reusing `PatientsController#transition`), the eligibility verdict with passing/out-of-reach/pending breakdown (reusing `CriteriaProfile#evaluate` → `EligibilityResult`), recent SOAP notes, and the complementary-information summary. It is the front door from `patients/show` ("Ver resumen"). No new model — pure assembly of the above.
- **Shared authorization pattern for all three sub-resources** (SOAP notes, complementary info, briefing): each is gated by the parent patient's visibility, NOT the `PermissionCatalog` matrix. The recipe is `set_patient` via `policy_scope(Patient).find` (out-of-reach → 404) + explicit `authorize(@patient, :show?/:update?)` + **override `authorization_model` to return `nil`** so `ResourceAuthorization` doesn't try (and fail) to find the sub-resource's model in the permission matrix. Copy this recipe for any future patient sub-resource.

### Global navbar search (added 2026-07-16)

The navbar search box posts to `GET /search` (`SearchController#index`). The logic lives in `GlobalSearch` (`app/services/global_search.rb`, a PORO — `app/services/` is Zeitwerk-autoloaded). It returns results **grouped by record type** (`Group` structs: `:studies`, `:trial_centers`, `:reps`, `:patients`, `:cities`) and is gated the same two ways the rest of the app is:

- **Permission** — each group only appears if the role has `can_show` on that resource (`Role#permits?`, the same flag the policies use). So a role with no `Patient` permission never gets a Patients group.
- **Scope** — a trial centre rep is limited to **their branch's** records (studies, patients via `PatientPolicy::Scope`, the branch/facility itself, its reps, its cities). Admins see everything. Other permitted roles see all rows of what they may view (no branch to scope by), matching the inherited Pundit scope.
- **Cities** carry the **user-scoped studies that run in them** (`CityResult` struct): studies of the branches located in that city, narrowed to the rep's branch. Note the city↔study link goes **through branches** (`City ↔ TrialCenterBranch ↔ Study`) — `Study` has no direct `cities` HABTM (it has `trial_cities`, a different thing).
- **`SearchController` `skip_after_action :verify_authorized`** — there's no single resource to `authorize`; GlobalSearch enforces authorization per record type instead. This is the one sanctioned exception to the deny-by-default rule.
- **Patient search caveat:** `Patient` name/email are deterministically encrypted, so search matches them by **exact value only** (ciphertext can't be `ILIKE`'d). `participant_code` is plaintext and matches partially. All other types match partially on their name/title columns.

### JavaScript

Import maps (no JS build step). Hotwire (Turbo + Stimulus) is available via the Gemfile, but check `app/javascript/controllers/` before assuming a given page is Stimulus-driven — usage is lighter than a fully Hotwire-native app.

### Styling

Bootstrap 5 (`bootstrap` gem) + `dartsass-rails`. Custom healthcare color palette overrides Bootstrap variables — documented in `docs/color_palette.md`. Reusable custom classes: `.health-card`, `.stat-card`. Follow the existing palette/contrast guidance in that doc rather than introducing new ad hoc colors.

### Pagination

`will_paginate` + `bootstrap-will_paginate`. `RECORDS_PER_PAGE = 12` is defined in `ApplicationController`.

### Database

PostgreSQL, single database — **for real since 2026-07-18**. Until then `config/database.yml` production still declared the Rails 8 default cache/queue/cable multi-DB split against databases that can never exist on Heroku's essential-0 plan (one database only), which made every Solid Queue enqueue raise. The solid_cache/solid_queue/solid_cable gems were removed; if the app ever grows a worker dyno, reintroduce Solid Queue deliberately (gem + tables + process), don't assume it's wired.

### Background jobs & Active Storage garbage collection (2026-07-18)

- **Jobs run in-process (`:async` adapter) in production.** There is no worker dyno; the app's only background jobs are Active Storage's own (analyze, purge) plus Action Text embed purges. `purge_later` therefore works, but a job pending during a dyno restart is lost — by design, because:
- **`PurgeUnattachedBlobsJob` is the safety net** (`app/jobs/`), run daily in production by **Heroku Scheduler** → `rails active_storage:purge_unattached`. It purges blobs with no attachment older than `TTL` (3 days): abandoned Trix uploads (images upload to S3 the moment they're pasted, before any submit), direct-upload files whose form failed validation or was never submitted, and blobs orphaned by lost purge jobs. **If the Scheduler job isn't configured, orphans accumulate silently** — that scheduled task is part of the design, not an optimization.
- **`rails active_storage:audit_orphans`** (report-only, never deletes) finds what the sweep can't: service files with no blob row, and blank rich texts still holding embeds (the pre-`store_if_blank` leak shape).
- **`store_if_blank: false` on every `has_rich_text`** (SoapNote ×4, ComplementaryInformation#notes). Two distinct clear paths, verified empirically (2026-07-18): assigning `""`/nil destroys the RichText row (this option); a **browser** clear submits `"<div><br></div>"` — present, so the row survives and it's Action Text's embed re-sync (`RichText#before_save`) that detaches the images. Both end with the blobs unattached and sweep-reclaimable; don't weaken either assuming the other covers it. Keep the option on any future `has_rich_text`.
- **Open follow-up (found in review 2026-07-18, deliberately not in that PR):** the blob-*serving* engine endpoints (`ActiveStorage::Blobs::*`, `Representations::*`, `DiskController`) authenticate by signed URL alone, and `config.active_storage.urls_expire_in` is unset — so a leaked `rails_blob_path` link to a patient's clinical file works **forever**. Consider setting `urls_expire_in` (Action Text bodies store never-expiring attachable sgids, not URL signed_ids, so old notes keep rendering — verify that before shipping).
- **The direct-upload endpoint requires login** (`config/initializers/active_storage_direct_uploads.rb`): every upload surface is staff-only and the public participation form takes no files, so anonymous blob minting (an orphan/cost/abuse surface) is blocked. If a patient-facing upload flow is ever built (see the ComplementaryInformation design note), this gate must be revisited alongside it.

### Deployment

**Production is Heroku** (app `medici`, Eco web dyno + essential-0 Postgres): deploy via `git push heroku main`, migrate with `heroku run rails db:migrate`. Heroku Scheduler must run `rails active_storage:purge_unattached` daily (see the garbage-collection section). The `.kamal/` config in the repo is vestigial — do not treat it as the deploy path.

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
- Processing sensitive data is prohibited by default; requires explicit, prior, informed authorization from the patient (Art. 6, 9), with a carve-out for medical/health emergencies (Art. 10). **Done (see task 3):** the public participation form (`ParticipationRequestsController`) captures this as a discrete, auditable step — not folded into a terms-of-service checkbox — and it is a hard gate, so no `Patient` row exists at all until it is granted.
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
- **Informed consent — concrete, actionable requirement:** the consent form must be signed and dated by (a) the participant (or legal representative/guardian for vulnerable populations), (b) **two witnesses**, and (c) the investigating physician ("médico investigador") — a wet-ink, multi-party signature requirement materially stricter than a single Ley 1581 habeas-data authorization. This is an audited checklist item (item 32 of INVIMA's institutional evaluation instrument) and the form must be re-signed/re-dated whenever amended. **Action:** medici_app's enrollment flow (public participation form → `Patient` AASM `prospect` → rep builds the clinical record) still has **no** multi-party consent capture — this remains an open compliance gap (task 4), and a Ley 1581 authorization checkbox does not satisfy it.
- **Participant sample/data handling (Tabla 7 of the Anexo Técnico):** requires a pseudonymization/coding system — participant identity must be linkable to research data only via codes, with records stored in a secure location accessible only to the study-responsible person. **Action:** verify `CriteriaVariable`/eligibility data in medici_app is coded/pseudonymized where it feeds into trial reporting, not just access-controlled via Pundit roles.
- **Explicitly NOT confirmed — flagged as open gaps, do not assume:**
  - How INVIMA consent legally interacts with Ley 1581 habeas-data authorization (whether one satisfies the other, or both are independently required) — no primary source found addressing this relationship. Treat as **layered/additional requirements** (the safer assumption, given INVIMA's requirements are structurally distinct and stricter) rather than substitutes, pending confirmation.
  - Electronic/digital informed consent permissibility — not addressed in sources reviewed.
  - Sponsor access rules to identifiable participant data, and data monitoring committee (DSMB) access — not addressed.
  - Cross-border transfer of participant data to international sponsors under INVIMA's regime specifically (distinct from the general Ley 1581 Art. 26 framework already documented above) — not addressed.
- **Correction to a previously-logged preliminary note:** an earlier hypothesis that informed-consent requirements trace to Resolución 8430 de 1993 rather than Resolución 2378 de 2008 did **not** survive adversarial verification (1-2 vote, not confirmed). Resolución 2378 de 2008's own Anexo Técnico is the confirmed, direct source of the consent requirements above — do not cite Resolución 8430 de 1993 for trial-specific informed consent without further dedicated verification.

Sources: [Resolución 2378 de 2008 (INVIMA)](https://mesagil.invima.gov.co/biblioteca/resolucion_20no_202378_20de_202008_1pdf), [INVIMA BPC certification page](https://www.invima.gov.co/productos-vigilados/medicamentos-y-productos-biologicos/medicamentos-de-sintesis-quimica-y-biologica/licenciamiento-auditorias-y-certificaciones/certificaciones-en-buenas-practicas), [Resolución 866 de 2021 (primary PDF)](https://www.minsalud.gov.co/sites/rid/Lists/BibliotecaDigital/RIDE/DE/DIJ/resolucion-866-de-2021.pdf).

### Compliance status vs. actual code (audited 2026-07-11 — HISTORICAL, mostly remediated)

> **Read this as a snapshot of 2026-07-11, not as current state.** It is kept because it is the audit that motivated the remediation work, and because it records exactly what was broken. **All of it except the INVIMA multi-party consent (task 4) has since been fixed** — see the task checklist below, which is the source of truth. Do not quote these findings as live gaps.

Checked the requirements above against the medici_app codebase directly (not inferred). Results as of that date — every item below was a confirmed gap, not a hypothesis:

- **Ley 1581 authorization capture at registration — NOT implemented.** `Users::RegistrationsController#create` ([app/controllers/users/registrations_controller.rb](app/controllers/users/registrations_controller.rb)) only handles the Devise sign-up plus auto-creating a `Patient`/`userable` tied to a `Study` when `study_id` is present in session. No consent/authorization field, checkbox, or step exists anywhere in the flow.
- **INVIMA informed consent (participant + 2 witnesses + investigating physician) — NOT implemented at all.** A repo-wide search for `consent`, `consentimiento`, `witness`, `testigo` returns zero results. No model, field, or view for this exists.
- **Participant data pseudonymization/coding (Anexo Técnico Tabla 7) — NOT implemented.** No coding/pseudonymization logic exists for `Patient` or `CriteriaVariable` data.
- **Audit trail — NOT implemented, despite the gem being present.** `paper_trail` is in the Gemfile but **`has_paper_trail` is declared on zero models** — confirms and closes out the earlier "not yet verified" flag as a confirmed gap.
- **Restricted access to sensitive clinical data — the most significant finding: NOT enforced for most actions.** In `app/controllers/patients_controller.rb`, Pundit's `authorize @patient, :update_state?` is called **only when the `state` param is present** (lines 38-42). The `index` action (`Patient.all`, unscoped), `show`, `edit`, `create`, and non-state `update` have **zero Pundit authorization**. Concrete consequence: **any authenticated user, regardless of role** (`SponsorRep`, `TrialCenterBranchRep`, `Admin`, or even another `Patient`), can list and view every patient's `dob`, `sex`, `illness_description`, and `notes`.
- **`StudyPolicy` is dead code.** It defaults every action (`index?`, `show?`, `create?`, `update?`, `destroy?`) to `false` with no overrides, but `app/controllers/studies_controller.rb` never calls `authorize` or `policy_scope` — the policy is never actually invoked.

**Priority for remediation:** the `PatientsController` access-control gap is the most urgent — it's a live, exploitable exposure of sensitive health data to any logged-in user, not just a future compliance-deadline risk like the interoperability question.

**Resolution (2026-07-15).** Closed in two passes, worth distinguishing because the first looked complete and wasn't:
1. *(2026-07-13, task 1)* `authorize` was wired for every standard action, deny-by-default. That fixed "any logged-in user can list patients" — a sponsor rep or platform staff now gets nothing.
2. *(2026-07-15)* **But it was still wide open between roles with access.** `PatientPolicy` had no `Scope`, so the inherited one returned `scope.all`: **every trial centre rep could list every patient of every study, including centres they had nothing to do with.** Resource-level authorization cannot express that — it is a row-level question. `PatientPolicy::Scope` now walks rep → branch → studies → patients, and `PatientsController` loads every action through `policy_scope`. Specs in `spec/policies/patient_policy_spec.rb` fail if the scope is removed. **Lesson for future work: `authorize` alone never restricts *which* records a permitted role sees — that always needs a Scope.**

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
   - **Done:** `Consent` model (immutable, versioned: document_type/version, purpose, granted_at, ip_address; `has_paper_trail`). A distinct habeas-data authorization checkbox, a hard gate: without it nothing is written at all (422, zero rows). Version bumps via `Consent::LEY_1581_CURRENT_VERSION`.
   - **Moved 2026-07-15:** the gate now lives on the **public participation form** (`ParticipationRequestsController#create`), not on Devise sign-up — that flow no longer exists. `Consent belongs_to :patient` (it was `belongs_to :user`; with no account there was nothing to attach it to). Rationale for keeping the gate at all: leaving a phone number against a *named clinical trial* discloses a health interest, so it is still sensitive data under Art. 5 and still needs prior authorization. Guarded by `spec/requests/participation_requests_spec.rb`.

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
   - **Done:** `sponsors.international` flag + `Study#international_sponsor?`. When the study's sponsor is international, the authorization shows an Art. 26 cross-border clause and a distinct `Consent` (`ley_1581_cross_border_transfer`) is recorded alongside the base one. _(2026-07-15: this moved from the sign-up form to the public participation form, unchanged in substance.)_
   - **Re-fit (2026-07-13, see "Offshore hosting" note above):** the real offshore data flow is **hosting on Heroku/AWS (US), which is a *transmisión* to a processor**, not a transferencia — handled by a **DPA (legal/process)** + a *transmisión* acknowledgment now in the **base** consent text (all patients), not by a per-patient opt-in. And **`Sponsor`s are only records** (no real data flow to them), so this sponsor cross-border consent is **precautionary, not legally triggered**. Remaining real item is **legal/process**: execute DPAs with Heroku/Salesforce + AWS and confirm the "responsable" is the trial site/sponsor entity.

- [ ] 8. **[MEDIUM — legal, not dev] Resolve the open INVIMA / Ley 1581 interaction questions.**
   - Not a development task: get legal confirmation on (a) whether INVIMA consent satisfies or stacks on top of Ley 1581 authorization, (b) electronic consent validity, (c) sponsor/DMC access rules to identifiable data.
   - Blocks the final design of tasks 3 and 4 — build the safer "both required" version now, revise once confirmed.
   - **Cross-border question RESOLVED (2026-07-13):** offshore hosting = *transmisión* (DPA, not per-patient consent); US is on the SIC adequacy list. Remaining legal items are the INVIMA consent questions (a/b/c above) + executing the hosting DPAs (a contract/process task, not code). See the "Offshore hosting" research note above.
