import { Controller } from "@hotwired/stimulus"

// Keeps a submit button disabled until the habeas-data checkbox is ticked, so
// the form cannot be sent without authorization.
//
// This is an affordance ONLY. The real gate is server-side
// (ParticipationRequestsController#create), which refuses an unauthorized
// request and writes nothing — a disabled attribute is trivially removed.
//
// The button is deliberately NOT disabled in the HTML: if this controller never
// runs (JS off or broken), the form stays usable and the server still refuses an
// unticked submission. Failing that way round means a broken script can never
// lock someone out of the form.
export default class extends Controller {
  static targets = ["checkbox", "submit"]

  // Also runs on Turbo cache restore, so a restored page can't come back with a
  // stale enabled button next to an unticked box.
  connect() {
    this.toggle()
  }

  toggle() {
    this.submitTarget.disabled = !this.checkboxTarget.checked
  }
}
