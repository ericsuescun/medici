class StaticPagesController < ApplicationController
  # Every other action here is deliberately public; the manual is not. It spells
  # out the permission matrix and the open compliance gaps, which is internal
  # operational detail — every signed-in role may read all of it, anonymous
  # visitors none. (The navbars that link it only render when signed in anyway.)
  before_action :authenticate_user!, only: :about

  def medici_home
    @cities = City.all.order(:name)
  end

  # Operation manual: what each role may do, the Colombian regulatory sources the
  # operation rests on, and the feature inventory. Content lives in
  # OperationManual.
  def about
    @roles = OperationManual::ROLES
    @documents = OperationManual::DOCUMENTS
    @internal_documents = OperationManual::INTERNAL_DOCUMENTS
    @shipped = OperationManual.shipped
    @outstanding = OperationManual.outstanding
  end

  def medici_showcase
  end

  # Public, read-only "More about this study" info card reachable from the home
  # showcase without logging in (the authenticated StudiesController#show is
  # behind Devise + Pundit, so anonymous visitors need this separate action).
  def study_details
    @study = Study.find(params[:id])
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
      @city_name = t("static_pages.no_city_selected")
    end
  end
end
