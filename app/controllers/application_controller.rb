class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  # PaperTrail no longer auto-installs this; wire whodunnit to the acting user so
  # every audited change is attributable. `user_for_paper_trail` defaults to
  # current_user.id (nil for unauthenticated requests).
  before_action :set_paper_trail_whodunnit
  before_action :set_locale

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  helper_method :analytics_allowed?

  RECORDS_PER_PAGE = 12

  private

  # Whether the Google/Meta measurement tags may load on this response.
  #
  # Deny by default, opt in per action (see StaticPagesController). The tags are
  # for the public marketing funnel; they must never fire from a page that says
  # something about a visitor's health. Concretely that rules out
  # ParticipationRequestsController (leaving contact details against a *named*
  # trial), SelfReportsController (the symptom questionnaire) and every
  # signed-in page — the same "dato sensible" reasoning as Ley 1581 de 2012,
  # Art. 5, that gates the participation form itself.
  #
  # A signed-in visitor is never measured either, whatever the action: staff
  # traffic is not marketing traffic, and it would skew every funnel number.
  def analytics_allowed?
    false
  end

  # Locale resolution: an explicit ?locale= param wins (and is remembered in the
  # session); otherwise the last chosen locale; otherwise the default (Spanish).
  def set_locale
    requested = params[:locale] || session[:locale]
    I18n.locale =
      if requested && I18n.available_locales.map(&:to_s).include?(requested.to_s)
        session[:locale] = requested
      else
        I18n.default_locale
      end
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: t("errors.not_authorized")
  end
end
