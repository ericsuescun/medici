class SecureApplicationController < ApplicationController
  include ResourceAuthorization

  before_action :authenticate_user!

  # NOTE: `after_action :verify_authorized` (deny-by-default guarantee) is enabled
  # in the final phase, once every controller — including custom member actions —
  # calls `authorize` and roles/permissions are seeded in every environment.
end
