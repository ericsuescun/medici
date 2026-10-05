# View-side plumbing for the measurement tags. The decision about whether to
# measure at all lives in ApplicationController#analytics_allowed?; this only
# translates that decision into attributes.
module AnalyticsHelper
  # Attributes for <body>. Empty (so the tag renders unchanged) on every page
  # that is not measured — which is why the analytics Stimulus controller simply
  # does not exist on those pages, rather than existing and staying quiet.
  def analytics_body_attributes
    return {} unless Analytics.enabled? && analytics_allowed?

    {
      data: {
        controller: "analytics",
        analytics_config_value: Analytics.browser_config.to_json,
        # Conversions the server observed on the previous request (a submitted
        # participation form, a completed questionnaire). Read once, on the next
        # measured page. `presence` keeps the attribute off the tag entirely when
        # there is nothing to report.
        analytics_events_value: Array(flash[:analytics_events]).presence&.to_json
      }.compact
    }
  end

  # Turns a link or button into a tracked call to action:
  #   link_to t("..."), path, class: "btn", **analytics_cta("click_participate")
  # The name must exist in the analytics controller's EVENTS map or nothing is
  # sent.
  def analytics_cta(event_name)
    return {} unless Analytics.enabled? && analytics_allowed?

    { data: { action: "click->analytics#track", analytics_name_param: event_name } }
  end
end
