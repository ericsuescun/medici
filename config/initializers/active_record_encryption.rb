# ActiveRecord::Encryption keys (pseudonymization of identifiable patient data —
# INVIMA Anexo Técnico Tabla 7). Production MUST supply real keys via ENV; a
# missing key raises here rather than silently falling back to a weak default.
# Generate a fresh set with `bin/rails db:encryption:init` and set on Heroku:
#   heroku config:set AR_ENCRYPTION_PRIMARY_KEY=... AR_ENCRYPTION_DETERMINISTIC_KEY=... AR_ENCRYPTION_KEY_DERIVATION_SALT=...
enc = Rails.application.config.active_record.encryption

if Rails.env.production?
  enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY")
  enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY")
  enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT")
else
  # Dev/test only — not secret, never used in production (guarded above).
  enc.primary_key         = ENV.fetch("AR_ENCRYPTION_PRIMARY_KEY", "dev_only_primary_key_qHCBfSl6KxwHZGRZy5Tg")
  enc.deterministic_key   = ENV.fetch("AR_ENCRYPTION_DETERMINISTIC_KEY", "dev_only_deterministic_FSaKBDMDLc6MrYzivbN9")
  enc.key_derivation_salt = ENV.fetch("AR_ENCRYPTION_KEY_DERIVATION_SALT", "dev_only_salt_B2PfQhnVCq7so1LOnpctnZb9k8mW75Cq")
end

# Read rows written before encryption was enabled (existing dev/prod data), and
# make deterministic queries match both encrypted and not-yet-encrypted values
# during the transition. Re-encrypt existing rows post-deploy, then these can be
# tightened. See lib/tasks/encryption.rake (patients:reencrypt).
enc.support_unencrypted_data = true
enc.extend_queries = true
