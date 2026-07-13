# Generic Pundit enforcement for the standard RESTful actions. Because
# permissions are resource-level (not row-level), authorizing the model *class*
# is equivalent to authorizing an instance and avoids depending on set_* load
# order. Pundit maps the current action_name to the policy predicate
# (index? / show? / new? / create? / edit? / update? / destroy?).
#
# Custom member actions (add_rep, transition, …) are NOT covered here — each
# must call `authorize` explicitly (and the verify_authorized after_action, once
# enabled, will flag any that don't).
module ResourceAuthorization
  extend ActiveSupport::Concern

  STANDARD_ACTIONS = %w[index show new edit create update destroy].freeze

  included do
    before_action :authorize_resource, if: :standard_resource_action?
  end

  private

  def standard_resource_action?
    STANDARD_ACTIONS.include?(action_name) && authorization_model
  end

  def authorize_resource
    authorize(authorization_model)
  end

  # Maps the controller to its model class (e.g. trial_center_branches ->
  # TrialCenterBranch). Returns nil for controllers without a matching model.
  def authorization_model
    controller_name.classify.constantize
  rescue NameError
    nil
  end
end
