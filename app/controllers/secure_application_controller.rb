class SecureApplicationController < ApplicationController
  include ResourceAuthorization

  before_action :authenticate_user!

  # Deny-by-default guarantee: every action under this controller must call
  # `authorize` (standard actions via ResourceAuthorization, custom member
  # actions explicitly). Any that doesn't raises Pundit::AuthorizationNotPerformed
  # in tests — surfacing a missed authorization as a failing spec, not a leak.
  # index is authorized too (resource-level), so no verify_policy_scoped.
  after_action :verify_authorized
end
