import { Controller } from "@hotwired/stimulus"

// Keeps a submit button disabled until every legally required box is ticked, so
// the form cannot be sent in a state the server is going to refuse.
//
// Two boxes gate the public participation form, and both are hard gates in
// ParticipationRequestsController#create: the habeas-data authorization (Ley
// 1581 Arts. 6 and 9 — health data needs prior explicit authorization) and the
// adult confirmation (Art. 7 — minors' data may not be processed). The gate used
// to watch only the first, so leaving the second unticked produced an enabled
// button, a round trip, and a 422 — and the authorization tick was lost on the
// way back, making somebody re-consent because of an unrelated field.
//
// This is an affordance ONLY. The real gate is server-side, which refuses an
// incomplete request and writes nothing — a disabled attribute is trivially
// removed.
//
// The button is deliberately NOT disabled in the HTML: if this controller never
// runs (JS off or broken), the form stays usable and the server still refuses an
// incomplete submission. Failing that way round means a broken script can never
// lock someone out of the form.
export default class extends Controller {
  static targets = ["required", "submit", "row", "hint", "consent"]

  // The hint has to name what is actually missing — "marca la autorización"
  // beside an already-ticked authorization is worse than no hint at all — so
  // the three cases come in as values rather than one fixed string.
  static values = { consentHint: String, adultHint: String, bothHint: String }

  // Also runs on Turbo cache restore, so a restored page can't come back with a
  // stale enabled button next to an unticked box.
  connect() {
    this.toggle()
  }

  toggle() {
    const missing = this.requiredTargets.filter((box) => !box.checked)

    this.submitTarget.disabled = missing.length > 0

    // Read the authorization state at a glance: the row goes green once given.
    if (this.hasRowTarget && this.hasConsentTarget) {
      this.rowTarget.classList.toggle("consent-row--granted", this.consentTarget.checked)
    }

    if (this.hasHintTarget) {
      this.hintTarget.hidden = missing.length === 0
      if (missing.length > 0) this.hintTarget.textContent = this.hintFor(missing)
    }
  }

  hintFor(missing) {
    if (missing.length > 1) return this.bothHintValue
    // Which single box is outstanding — the consent one is identifiable because
    // it carries its own target.
    const onlyConsent = this.hasConsentTarget && missing[0] === this.consentTarget
    return onlyConsent ? this.consentHintValue : this.adultHintValue
  }
}
