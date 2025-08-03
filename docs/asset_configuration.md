# Asset Configuration Documentation

This document outlines the configuration for assets in the Medici application, particularly focusing on how images are handled.

## Asset Pipeline Configuration

The Medici application uses Propshaft as its asset pipeline. The following configurations have been made to ensure proper asset loading:

### 1. Asset Path Configuration

In `config/initializers/assets.rb`, we've added the following paths to the asset load path:

```ruby
Rails.application.config.assets.paths << Rails.root.join("app/assets/images")
Rails.application.config.assets.paths << Rails.root.join("app/assets/images/logo")
Rails.application.config.assets.precompile += %w( logo/medici_logo.png )
```

This ensures that the images directory and the logo subdirectory are included in the asset load path, and that the logo image is explicitly precompiled.

### 2. Direct Asset Access

For certain images that need to be directly accessible, we've placed them in the `public/assets` directory. This approach bypasses the asset pipeline and makes the images directly accessible via URL.

For example, the Medici logo is accessible at:

```
/assets/logo/medici_logo.png
```

This approach is used in the view with:

```erb
<%= image_tag "/assets/logo/medici_logo.png", alt: "Medici Logo", class: "img-fluid", style: "max-height: 150px;" %>
```

## Asset Management Strategy

The application uses a hybrid approach for asset management:

1. **Asset Pipeline (Propshaft)**: Used for most assets, including stylesheets and JavaScript files.
2. **Direct Public Access**: Used for specific images that need to be directly accessible, such as the logo.

## Troubleshooting Asset Issues

If you encounter issues with assets not loading:

1. Check if the asset is properly included in the asset load path in `config/initializers/assets.rb`.
2. For images that need direct access, ensure they are placed in the appropriate directory under `public/assets/`.
3. Clear the asset cache by running `rails assets:clobber` followed by `rails assets:precompile`.
4. Restart the Rails server to ensure configuration changes take effect.

## Future Considerations

As the application grows, consider:

1. Implementing a more structured approach to asset organization.
2. Using a CDN for serving assets in production.
3. Implementing image optimization as part of the asset pipeline.