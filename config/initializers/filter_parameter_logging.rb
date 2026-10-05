# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # The public self-report questionnaire (SelfReportsController, POST
  # /studies/:id/participate/questions): its answers are health data (Ley 1581,
  # Art. 5 — dato sensible) and must never reach the request log or any log drain.
  :answers, :declined, :reported_city, :files, :future_studies_authorization
]
