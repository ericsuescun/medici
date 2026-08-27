# Configuration for the third-party measurement tags (Google + Meta) used to
# attribute traffic from the social-media launch.
#
# Everything is read from ENV so no ID is ever committed, and so a review app or
# a developer's machine cannot pollute the production property. Set on Heroku
# with:
#   heroku config:set GA4_MEASUREMENT_ID=G-XXXXXXX META_PIXEL_ID=000000000000000
#
# WHERE THESE TAGS ARE ALLOWED TO RUN is not decided here — see
# ApplicationController#analytics_allowed?. The short version: public marketing
# pages only. A pageview from "/studies/7/participate" would tell Google and Meta
# that this browser is trying to enrol in a *named clinical trial*, which is a
# statement about someone's health — the same "dato sensible" (Ley 1581 de 2012,
# Art. 5) that ParticipationRequestsController already gates behind an explicit
# authorization. So the tags never load on that form, on the self-report
# questionnaire, or on any signed-in page.
module Analytics
  module_function

  # Google Analytics 4 property ("G-XXXXXXX"). Traffic and behaviour reporting.
  def ga4_measurement_id
    ENV["GA4_MEASUREMENT_ID"].presence
  end

  # Google Ads account ("AW-XXXXXXXXX"). Only needed to report conversions back
  # to a paid campaign; GA4 alone is enough for organic social posts.
  def google_ads_id
    ENV["GOOGLE_ADS_ID"].presence
  end

  # The per-conversion label Google Ads issues alongside the account id. Google's
  # own snippet writes it as "AW-123/AbC-D_efG", which is what #google_ads_lead
  # rebuilds below.
  def google_ads_lead_label
    ENV["GOOGLE_ADS_LEAD_LABEL"].presence
  end

  def google_ads_lead
    return nil if google_ads_id.blank? || google_ads_lead_label.blank?

    "#{google_ads_id}/#{google_ads_lead_label}"
  end

  # Meta (Facebook/Instagram) pixel id — a 15-16 digit number.
  def meta_pixel_id
    ENV["META_PIXEL_ID"].presence
  end

  # Ownership-proof meta tags. These are NOT tracking: Search Console uses one to
  # confirm we own the domain before it will show indexing data, and Meta
  # Business Manager uses the other before it will let us configure events for
  # the domain. They carry no visitor data and so are exempt from the consent
  # gate below.
  def google_site_verification
    ENV["GOOGLE_SITE_VERIFICATION"].presence
  end

  def meta_domain_verification
    ENV["META_DOMAIN_VERIFICATION"].presence
  end

  def google?
    ga4_measurement_id.present? || google_ads_id.present?
  end

  def meta?
    meta_pixel_id.present?
  end

  # Off unless at least one id is configured. ANALYTICS_ENABLED exists so the
  # tags can be exercised on a review app (set it to "true" there) or switched
  # off in production without unsetting every id.
  def enabled?
    return false unless google? || meta?

    ActiveModel::Type::Boolean.new.cast(
      ENV.fetch("ANALYTICS_ENABLED", Rails.env.production?.to_s)
    )
  end

  # Handed to the browser as JSON. Only ids and flags — never anything about the
  # visitor or the study they are looking at.
  def browser_config
    {
      ga4: ga4_measurement_id,
      ads: google_ads_id,
      adsLead: google_ads_lead,
      meta: meta_pixel_id
    }.compact
  end
end
