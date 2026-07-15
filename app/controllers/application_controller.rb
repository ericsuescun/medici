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

  RECORDS_PER_PAGE = 12

  private

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
