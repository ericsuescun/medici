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

  # URL for switching to `locale`, preserving the current path and query.
  def locale_switch_url(locale)
    url_for(request.query_parameters.merge(locale: locale))
  end

  # Returns [ [name, code], ... ] for use in selects, ordered by country_priority then name
  # If no selected value is provided, defaults to 'CO' (Colombia)
  def country_options_for_select(selected = nil)
    selected ||= "CO"
    options = Country.order(country_priority: :asc, name: :asc).pluck(:name, :code)
    options_for_select(options, selected)
  end
end
