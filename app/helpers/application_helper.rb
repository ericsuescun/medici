module ApplicationHelper
  def get_age(date)
    if date == nil
      return ""
    else
      days = Date.today - date
      if days >= 365
        return "#{(days / 365).to_i} Años"
      end
      if days >= 30
        return "#{(days / 30).to_i} Meses"
      end
      return "#{days.to_i} Dias"
    end
  end

  # Returns [ [name, code], ... ] for use in selects, ordered by country_priority then name
  # If no selected value is provided, defaults to 'CO' (Colombia)
  def country_options_for_select(selected = nil)
    selected ||= 'CO'
    options = Country.order(country_priority: :asc, name: :asc).pluck(:name, :code)
    options_for_select(options, selected)
  end
end
