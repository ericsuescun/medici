# The Active Storage engine's direct-upload endpoint
# (POST /rails/active_storage/direct_uploads) ships unauthenticated, so anyone
# on the internet could mint blob records and upload files straight into the
# S3 bucket. Every upload surface in this app is staff-only (SOAP notes,
# complementary information, campaign documents) and the public participation
# form takes no files, so requiring a signed-in user here blocks anonymous
# blob creation without affecting any real flow.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action :authenticate_user!
end
