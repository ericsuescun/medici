# frozen_string_literal: true

class StaticPagePolicy < ApplicationPolicy
  # Controls visibility of the "Buscar Estudios por Ciudad" section on the home page
  def search_by_city?
    return false if user&.patient?
    true
  end

  # Controls visibility of the navigation buttons on home for signed-in users
  def home_navigation?
    return false if user&.patient?
    true
  end
end
