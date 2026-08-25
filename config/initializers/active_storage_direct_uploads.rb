# The Active Storage engine's direct-upload endpoint
# (POST /rails/active_storage/direct_uploads) ships unauthenticated, so anyone
# on the internet could mint blob records and upload files straight into the
# S3 bucket. Requiring a signed-in user blocks anonymous blob creation without
# affecting any real flow.
#
# As of 2026-08-24 NO `file_field` in this app passes `direct_upload: true` any
# more — every explicit file upload (complementary information, the public
# self-report questionnaire) is a plain multipart POST that the controller
# attaches server-side, so there is ONE upload path to reason about.
#
# This gate still matters, and the endpoint is still live, because Action Text
# uses it from JS: `@rails/actiontext` registers a `trix-attachment-add`
# handler that fires a DirectUpload the moment an image is dropped into a Trix
# field (ComplementaryInformation#notes). That is not a `direct_upload: true`
# attribute and does not go away with them — do not delete this initializer or
# `ActiveStorage.start()` on the assumption that it did.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.before_action :authenticate_user!
end
