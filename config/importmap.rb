# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
pin "trix", to: "trix.esm.min.js"
pin "@rails/actiontext", to: "actiontext.esm.js"
# Required by Action Text, NOT by any file field: as of 2026-08-24 no
# `file_field` passes `direct_upload: true` — every explicit upload is plain
# multipart. `@rails/actiontext` still imports DirectUpload from here to push
# images dropped into a Trix editor straight to S3, so this pin and the
# `ActiveStorage.start()` in application.js both stay.
pin "@rails/activestorage", to: "activestorage.esm.js"
