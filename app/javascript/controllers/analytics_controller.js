import { Controller } from "@hotwired/stimulus"

// Drives the Google/Meta measurement tags from the public marketing pages.
//
// The server decides WHETHER this controller is on the page at all
// (ApplicationController#analytics_allowed?); this decides WHAT is sent, and
// sends nothing at all until the visitor accepts in the consent banner.
//
// Three jobs:
//   1. Consent. Remembered in localStorage, applied to Google via Consent Mode
//      and to Meta by simply not loading the pixel until it is granted.
//   2. Pageviews. Turbo swaps pages inside one document, so gtag's automatic
//      pageview would only ever fire on the first load — every view is sent by
//      hand from connect() instead.
//   3. Events. The "¡Quiero participar!" click, and the conversion the server
//      flags through flash after a request is actually submitted.
export default class extends Controller {
  static values = {
    config: Object,   // { ga4, ads, adsLead, meta } — ids only, no visitor data
    events: Array     // one-shot conversions the server asked us to report
  }
  static targets = ["banner"]

  static STORAGE_KEY = "medici.analytics.consent"

  // What each of our event names becomes for each vendor. Meta only recognises a
  // fixed list of standard events (Lead, CompleteRegistration, ...); anything
  // else has to go through trackCustom or it is silently dropped.
  static EVENTS = {
    click_participate: {
      ga4: "click_participate",
      meta: { name: "ClickParticipate", standard: false }
    },
    participation_submitted: {
      ga4: "generate_lead",
      meta: { name: "Lead", standard: true },
      adsConversion: true
    },
    self_report_completed: {
      ga4: "submit_questionnaire",
      meta: { name: "CompleteRegistration", standard: true }
    }
  }

  connect() {
    // Turbo renders a cached copy of the page before the fresh one arrives.
    // Counting that preview would double every pageview.
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.decision = this.storedDecision()

    if (this.decision === "granted") {
      this.enableVendors()
      this.reportPageView()
      this.reportPendingEvents()
    } else if (this.decision !== "denied") {
      this.showBanner()
    }
  }

  // --- consent -------------------------------------------------------------

  accept() {
    this.persist("granted")
    this.hideBanner()
    this.enableVendors()
    this.reportPageView()
    this.reportPendingEvents()
  }

  reject() {
    this.persist("denied")
    this.hideBanner()
    // Nothing to undo: with the decision absent we never loaded a vendor tag,
    // so there is no cookie or pixel to clear.
  }

  storedDecision() {
    try {
      return window.localStorage.getItem(this.constructor.STORAGE_KEY)
    } catch (e) {
      // Safari in private mode throws on localStorage. Treat it as "no decision
      // yet": the banner shows again next visit, and nothing is sent meanwhile.
      return null
    }
  }

  persist(decision) {
    this.decision = decision
    try {
      window.localStorage.setItem(this.constructor.STORAGE_KEY, decision)
    } catch (e) {
      // Non-fatal — the decision still holds for this page view.
    }
  }

  showBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = false
  }

  hideBanner() {
    if (this.hasBannerTarget) this.bannerTarget.hidden = true
  }

  enableVendors() {
    if (typeof window.gtag === "function") {
      window.gtag("consent", "update", {
        ad_storage: "granted",
        ad_user_data: "granted",
        ad_personalization: "granted",
        analytics_storage: "granted",
        functionality_storage: "granted",
        personalization_storage: "granted"
      })
    }
    this.loadMetaPixel()
  }

  // Meta has no Consent Mode equivalent, so the pixel is injected only once the
  // visitor has accepted — before that its script is never fetched.
  loadMetaPixel() {
    const id = this.configValue.meta
    if (!id || window.fbq) return

    /* eslint-disable */
    !function (f, b, e, v, n, t, s) {
      if (f.fbq) return; n = f.fbq = function () {
        n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments)
      };
      if (!f._fbq) f._fbq = n; n.push = n; n.loaded = !0; n.version = "2.0"; n.queue = [];
      t = b.createElement(e); t.async = !0; t.src = v;
      s = b.getElementsByTagName(e)[0]; s.parentNode.insertBefore(t, s)
    }(window, document, "script", "https://connect.facebook.net/en_US/fbevents.js")
    /* eslint-enable */

    window.fbq("init", id)
  }

  // --- reporting -----------------------------------------------------------

  reportPageView() {
    if (window.gtag && this.configValue.ga4) {
      window.gtag("event", "page_view", {
        page_location: this.sanitizedUrl(),
        page_title: this.sanitizedTitle()
      })
    }
    if (window.fbq) window.fbq("track", "PageView")
  }

  // Fired by the server through flash after a form was actually submitted —
  // that is the conversion, not the click that opened the form.
  reportPendingEvents() {
    this.eventsValue.forEach((name) => this.send(name))
  }

  // data-action="click->analytics#track" data-analytics-name-param="..."
  track(event) {
    const name = event.params.name
    if (name) this.send(name)
  }

  send(name) {
    const map = this.constructor.EVENTS[name]
    if (!map || this.decision !== "granted") return

    if (window.gtag && this.configValue.ga4) {
      window.gtag("event", map.ga4)
    }
    if (window.gtag && map.adsConversion && this.configValue.adsLead) {
      window.gtag("event", "conversion", { send_to: this.configValue.adsLead })
    }
    if (window.fbq) {
      window.fbq(map.meta.standard ? "track" : "trackCustom", map.meta.name)
    }
  }

  // A study's numeric id in the path would tell Google which trial this browser
  // is reading about. The page is public, but the interest it reveals is not the
  // kind of thing to hand over by default, and per-study numbers are better read
  // from our own database anyway. "/studies/42/about" is reported as
  // "/studies/detail".
  sanitizedUrl() {
    const url = new URL(window.location.href)
    url.pathname = url.pathname.replace(/\/studies\/\d+(?=\/|$)/, "/studies/detail")
    url.search = url.search.replace(/([?&])(study_id|id)=\d+/g, "$1$2=detail")
    return url.toString()
  }

  sanitizedTitle() {
    return document.title.includes("Medici") ? document.title : "Medici"
  }
}
