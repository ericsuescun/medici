module StudiesHelper
  def get_age(date)
    if date == nil
      ""
    else
      days = Date.today - date
      if days >= 365
        return "#{(days / 365).to_i} Años"
      end
      if days >= 30
        return "#{(days / 30).to_i} Meses"
      end
      "#{days.to_i} Dias"
    end
  end
end
