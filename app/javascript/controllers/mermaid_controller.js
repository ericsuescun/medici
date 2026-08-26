import { Controller } from "@hotwired/stimulus"

// Renders the per-role flow diagrams on /manual.
//
// Mermaid itself is NOT imported here. It is a 3.5 MB UMD bundle loaded by a
// plain script tag in that page's `content_for :head`, so only that page pays
// for it — importing it through the importmap would put it in the module graph
// of every page in the app. This controller is the glue: it waits for the global
// to appear and then renders.
//
// A Stimulus controller rather than a DOMContentLoaded listener because of
// Turbo: navigating to /manual from another page never fires DOMContentLoaded,
// and Turbo appends the head script asynchronously, so a `turbo:load` handler
// can easily run before the bundle has finished parsing. `connect()` fires on
// every visit, and the poll below covers the load race in both directions.
export default class extends Controller {
  static values = { attempts: { type: Number, default: 0 } }

  connect() {
    this.cancelled = false
    this.render()
  }

  disconnect() {
    this.cancelled = true
    if (this.timer) clearTimeout(this.timer)
  }

  render() {
    if (this.cancelled) return

    if (!window.mermaid) {
      // ~10s of patience at 50ms, then give up quietly: the <pre> blocks stay
      // readable as text, which is a worse diagram but not a broken page.
      if (this.attemptsValue > 200) return
      this.attemptsValue += 1
      this.timer = setTimeout(() => this.render(), 50)
      return
    }

    window.mermaid.initialize({
      startOnLoad: false,
      // The diagrams are authored in this repo, never user input, but strict is
      // the right default for something that injects SVG into the page.
      securityLevel: "strict",
      theme: "neutral",
      flowchart: { useMaxWidth: true, htmlLabels: true }
    })

    // Already-rendered nodes carry data-processed and are skipped, so running
    // again after a Turbo visit is harmless.
    window.mermaid.run({ querySelector: ".mermaid" })
  }
}
