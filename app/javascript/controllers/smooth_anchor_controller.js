import { Controller } from "@hotwired/stimulus"

// Reliable in-page navigation for the /about manual.
//
// A native `#anchor` jump drifts here: the layout sets `body { padding-top }`
// from JS *after* paint to clear the `fixed-top` navbar, and that late reflow
// (plus Chrome scroll anchoring) lands the jump a non-deterministic ~200px past
// its target — scroll-margin-top does not fix it. So we intercept the click and
// scroll ourselves, subtracting the navbar's live height, once layout has
// settled. Because the click happens long after load, offsets are stable.
//
// Falls back to default behavior if JS is off or the target is missing: the
// links are real `href="#id"` anchors, so they still jump (just with the drift).
export default class extends Controller {
  jump(event) {
    const href = event.currentTarget.getAttribute("href")
    if (!href || !href.startsWith("#")) return

    const target = document.getElementById(href.slice(1))
    if (!target) return

    event.preventDefault()
    this.scrollTo(target, href)
  }

  scrollTo(target, hash) {
    const nav = document.querySelector(".navbar.fixed-top")
    const offset = (nav ? nav.offsetHeight : 0) + 16
    const top = target.getBoundingClientRect().top + window.pageYOffset - offset

    window.scrollTo({ top, behavior: "smooth" })
    // Update the URL without triggering another (drifting) native jump.
    if (window.history && window.history.replaceState) {
      window.history.replaceState(null, "", hash)
    }
    target.setAttribute("tabindex", "-1")
    target.focus({ preventScroll: true })
  }
}
