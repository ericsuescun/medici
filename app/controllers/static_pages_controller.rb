class StaticPagesController < ApplicationController
  def medici_home
    @cities = City.all.order(:name)
  end

  def medici_showcase
  end

  def search_by_city
    @city = City.find(params[:city_id]) if params[:city_id].present?

    if @city
      @studies = Study.joins(:trial_center_branches)
                      .joins("INNER JOIN cities_trial_center_branches ON cities_trial_center_branches.trial_center_branch_id = trial_center_branches.id")
                      .where("cities_trial_center_branches.city_id = ?", @city.id)
                      .distinct

      @city_name = @city.name
    else
      @studies = []
      @city_name = "No city selected"
    end
  end
end
