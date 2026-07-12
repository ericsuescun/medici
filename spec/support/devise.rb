RSpec.configure do |config|
  # `sign_in` / `sign_out` for request specs.
  config.include Devise::Test::IntegrationHelpers, type: :request

  # Capybara feature specs run through a separate Rack app, so they authenticate
  # with Warden's `login_as user, scope: :user` rather than the integration
  # `sign_in`. Pass an explicit scope to avoid Devise's mapping lookup (which
  # inspects the user and can trip the User -> userable delegation on non-patient
  # roles — see the delegated_type notes).
  config.include Warden::Test::Helpers, type: :feature

  config.before(:suite) { Warden.test_mode! }
  config.after(:each, type: :feature) { Warden.test_reset! }
end
