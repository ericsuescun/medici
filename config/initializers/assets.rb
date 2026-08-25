# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Include the build output directory for cssbundling-rails (application.css generated here)
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap-icons/font")
Rails.application.config.assets.paths << Rails.root.join("node_modules/bootstrap/dist/js")
# Action Text editor (Trix) + its Active Storage direct-upload glue, served the
# same node_modules way as bootstrap so importmap can pin them.
Rails.application.config.assets.paths << Rails.root.join("node_modules/trix/dist")
Rails.application.config.assets.paths << Rails.root.join("node_modules/@rails/actiontext/app/assets/javascripts")
Rails.application.config.assets.paths << Rails.root.join("node_modules/@rails/activestorage/app/assets/javascripts")
Rails.application.config.assets.paths << Rails.root.join("app/assets/images")
Rails.application.config.assets.precompile << "bootstrap.bundle.min.js"
Rails.application.config.assets.precompile += %w[ trix.esm.min.js actiontext.esm.js actiontext.css activestorage.esm.js ]
