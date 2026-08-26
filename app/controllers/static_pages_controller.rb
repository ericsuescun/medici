class StaticPagesController < ApplicationController
  # Every other action here is deliberately public; the manual is not. It spells
  # out the permission matrix and the open compliance gaps, which is internal
  # operational detail — every signed-in role may read all of it, anonymous
  # visitors none. (The navbars that link it only render when signed in anyway.)
  before_action :authenticate_user!, only: %i[about manual]

  def medici_home
    @cities = City.all.order(:name)
    # Public category filter: pills on the showcase link back here with
    # ?category=<id>. An unknown/blank id just falls back to all studies.
    @categories = Category.in_use
    @selected_category = Category.find_by(id: params[:category])
    @studies = @selected_category ? Study.by_category(@selected_category.id).distinct : Study.all
    @recruitment = RecruitmentProgress.for(@studies)
  end

  # The per-role operation manual: what each role does, drawn as a Mermaid flow,
  # plus the permission table behind it. Split off #about on 2026-08-25 — it is
  # the longest section by far and it is read on its own, to answer "what does
  # this role do", not alongside the regulatory sources.
  def manual
    @roles = OperationManual::ROLES
  end

  # How a patient moves through the recruitment lifecycle, the Colombian
  # regulatory sources the operation rests on, and the feature inventory.
  # Content lives in OperationManual.
  def about
    @roles_count = OperationManual::ROLES.size
    @patient_states = OperationManual::PATIENT_STATES
    @patient_transitions = OperationManual::PATIENT_TRANSITIONS
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

      # Which of the city's branches run each study, for the result cards.
      # One query up front instead of walking branch↔study per card.
      @branches_by_study = Hash.new { |h, k| h[k] = [] }
      @city.trial_center_branches.includes(:trial_center_facility, :studies).each do |branch|
        branch.studies.each { |study| @branches_by_study[study.id] << branch }
      end

      @city_name = @city.name
    else
      @studies = []
      @branches_by_study = {}
      @city_name = t("static_pages.no_city_selected")
    end

    @recruitment = RecruitmentProgress.for(@studies)
  end
end
