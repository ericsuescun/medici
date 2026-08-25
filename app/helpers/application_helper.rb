module ApplicationHelper
  def get_age(date)
    return "" if date.nil?

    days = Date.today - date
    if days >= 365
      t("common.age.years", count: (days / 365).to_i)
    elsif days >= 30
      t("common.age.months", count: (days / 30).to_i)
    else
      t("common.age.days", count: days.to_i)
    end
  end

  # Translated, human-readable label for a model's enum value. Looks up
  # `enums.<model>.<attribute>.<value>` and falls back to a humanized value.
  # Usage in a view: <%= t_enum(@sponsor, :sponsor_type) %>
  def t_enum(record, attribute)
    value = record.public_send(attribute)
    return "" if value.blank?

    t("enums.#{record.model_name.i18n_key}.#{attribute}.#{value}", default: value.to_s.humanize)
  end

  # The two badges an eligibility rule carries. Both use Bootstrap 5.3's
  # `-bg-subtle` / `-text-emphasis` token pairs rather than solid fills or
  # hand-rolled hexes: a rule table is a dense grid, and four saturated badges
  # per row shout over the data they are meant to annotate. The token pairs are
  # also contrast-checked by Bootstrap and swap correctly under a dark theme,
  # which is the direction of task D4.
  #
  # Colour carries meaning, so the two axes stay visually distinct:
  #   variable_type      green = inclusion, red = exclusion  (does it let you in
  #                      or keep you out)
  #   criteria_category  blue = primary, grey = secondary    (does it decide
  #                      anything)
  def criteria_category_badge(variable)
    tone = variable.primary? ? "primary" : "secondary"
    tag.span(t_enum(variable, :criteria_category),
             class: "badge border bg-#{tone}-subtle text-#{tone}-emphasis")
  end

  def variable_type_badge(variable)
    tone = variable.variable_type == "inclusion" ? "success" : "danger"
    tag.span(t_enum(variable, :variable_type),
             class: "badge border bg-#{tone}-subtle text-#{tone}-emphasis")
  end

  # A read-only on/off flag, rendered as a ticked or empty checkbox. Reads
  # faster down a column than a Sí/No badge does, and — unlike a coloured badge
  # — it does not compete with the inclusion/exclusion and primary/secondary
  # badges on the same row, which are the ones that actually carry meaning.
  #
  # `disabled` rather than `readonly`: checkboxes ignore readonly. These sit in
  # display tables, never inside a form, so nothing is lost by not submitting.
  # The label is spelled into aria-label/title because a bare checkbox in a grid
  # tells a screen reader (and a hovering mouse) nothing about what it is.
  def boolean_checkbox(checked, label:)
    description = "#{label}: #{checked ? t('common.yes') : t('common.no')}"
    tag.input(type: "checkbox", checked: checked, disabled: true,
              class: "form-check-input", title: description,
              aria: { label: description })
  end

  # One criterion's outcome for this patient. Same Bootstrap token family as the
  # other rule badges, so a row reads as one visual system:
  #   pass -> green, fail -> red, unmeasured -> grey.
  # `:missing` is its own state on purpose — "not measured" is not "fails", and
  # collapsing them would misreport an unmeasured exclusion as a pass.
  CHECK_STATUS_TONES = {
    pass: [ "success", "pass" ],
    fail: [ "danger", "fail" ]
  }.freeze
  CHECK_STATUS_UNMEASURED = [ "secondary", "no_data" ].freeze

  def check_status_badge(check)
    tone, key = CHECK_STATUS_TONES.fetch(check.status, CHECK_STATUS_UNMEASURED)
    tag.span(t("criteria_assessments.#{key}"),
             class: "badge border bg-#{tone}-subtle text-#{tone}-emphasis")
  end

  # A rule's patient-facing question, or a muted dash. Blank is meaningful — it
  # is what makes a rule un-askable — so it gets a visible placeholder rather
  # than an empty cell. Plain-String return is escaped by ERB, which matters:
  # the prompt is staff-entered text.
  def patient_prompt_display(variable)
    return tag.span("—", class: "text-muted") if variable.patient_prompt.blank?

    variable.patient_prompt
  end

  # URL for switching to `locale`, preserving the current path and query.
  def locale_switch_url(locale)
    url_for(request.query_parameters.merge(locale: locale))
  end

  # Returns a user-supplied URL only if it uses a safe http(s) scheme, otherwise
  # nil. Guards `link_to` hrefs against `javascript:`/`data:` URI injection when
  # the URL comes from a record (campaign document, article, contact).
  def safe_external_url(url)
    return if url.blank?

    normalized = url.to_s.strip
    normalized if normalized.match?(%r{\Ahttps?://}i)
  end

  # Returns [ [name, code], ... ] for use in selects, ordered by country_priority then name
  # If no selected value is provided, defaults to 'CO' (Colombia)
  def country_options_for_select(selected = nil)
    selected ||= "CO"
    options = Country.order(country_priority: :asc, name: :asc).pluck(:name, :code)
    options_for_select(options, selected)
  end
end
