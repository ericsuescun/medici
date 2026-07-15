# Production stores Active Storage files on S3 (see config/storage.yml): Heroku's
# filesystem is ephemeral, so the Disk service would silently lose every uploaded
# CampaignDocument on the next dyno restart.
#
# That makes the AWS config vars a hard boot requirement in production — eager
# loading resolves the S3 service at startup, so they are not optional. Fail here,
# legibly. Without this guard, boot dies deep inside the AWS SDK with
# `Aws::Errors::MissingRegionError`, and only after a ~10s hang probing the EC2
# instance metadata endpoint (169.254.169.254) — which reads like a network fault
# rather than unset configuration. Initializers run before eager loading, so this
# raises first.
#
# Same philosophy as config/initializers/active_record_encryption.rb: production
# must supply real values, and a missing one raises rather than silently degrading.
if Rails.env.production?
  required = %w[ AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_S3_BUCKET ]
  missing = required.reject { |name| ENV[name].present? }

  if missing.any?
    raise <<~MESSAGE
      Active Storage is configured for S3 but #{missing.to_sentence} #{missing.one? ? "is" : "are"} not set.

      Set them before deploying:
        heroku config:set --app medici #{missing.map { |name| "#{name}=..." }.join(" ")}
    MESSAGE
  end
end
