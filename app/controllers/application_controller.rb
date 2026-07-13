class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  before_action :configure_permitted_parameters, if: :devise_controller?
  # PaperTrail no longer auto-installs this; wire whodunnit to the acting user so
  # every audited change is attributable. `user_for_paper_trail` defaults to
  # current_user.id (nil for unauthenticated requests).
  before_action :set_paper_trail_whodunnit

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  RECORDS_PER_PAGE = 12

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :study_id ])
  end

  private

  def user_not_authorized
    redirect_back fallback_location: root_path,
                  alert: "No está autorizado para realizar esta acción."
  end
end
