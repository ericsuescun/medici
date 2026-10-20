import { Controller } from "@hotwired/stimulus"

// Shows the "ask online" switch on the criteria variable form only while the
// rule is SPECIFIC. A basic question is always asked online — the model forces
// it (CriteriaVariable#ask_basic_criteria_online) — so offering the switch on a
// basic rule would be a control that silently does nothing.
//
// The server renders the right initial state with `hidden`, so with JS off the
// form is still correct for the category it was loaded with; this only follows
// the select when somebody changes it.
export default class extends Controller {
  static targets = ["category", "specificOnly"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.specificOnlyTarget.hidden = this.categoryTarget.value !== "specific"
  }
}
