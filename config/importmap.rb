# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
pin "trix", to: "trix.esm.min.js"
pin "@rails/actiontext", to: "actiontext.esm.js"
# Direct-to-S3 uploads for plain file fields (direct_upload: true), e.g. the
# complementary-information PDFs/images. Action Text handles its own image
# uploads; this covers the non-Trix file inputs.
pin "@rails/activestorage", to: "activestorage.esm.js"
