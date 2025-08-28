# Medici App

Medici is a healthcare application designed to connect patients with clinical trials and medical services.

## Features

* User management for patients, sponsors, and administrators
* Trial center branch management
* Study management and tracking
* Patient enrollment in clinical trials

## Technology Stack

* Ruby on Rails
* Bootstrap for UI components
* PostgreSQL database

## UI Design and Styling

The application uses a healthcare-focused color palette designed to convey trust, professionalism, and a sense of calm. The color scheme has been implemented by overriding Bootstrap variables to maintain consistency throughout the application.

### Color Palette

The main colors used in the application are:

* Primary Blue (#2c7bb6): Used for primary actions, links, and headers
* Secondary Green (#16a085): Used for secondary actions and success states
* Success Green (#27ae60): Used for success messages and positive indicators
* Info Blue (#3498db): Used for information messages
* Warning Amber (#f39c12): Used for warnings and attention-required elements
* Danger Red (#e74c3c): Used for error messages and destructive actions

For a complete documentation of the color palette, please refer to [docs/color_palette.md](docs/color_palette.md).

### Custom Components

The application includes several custom-styled components:

* `.health-card`: A card with a left border accent
* `.stat-card`: A card for displaying statistics with hover effects
* Enhanced table styling with improved readability
* Custom button and link styling for better accessibility

## Development

### Setup

1. Clone the repository
2. Install dependencies with `bundle install`
3. Set up the database with `rails db:setup`
4. Start the server with `rails server`

### Styling Guidelines

When adding new UI components:

1. Use the existing color variables defined in `app/assets/stylesheets/custom.scss`
2. Follow the Bootstrap component structure
3. Ensure all UI elements are accessible and have sufficient color contrast
4. Refer to the color palette documentation for guidance on color usage

## Deployment (Heroku)

This app uses Rails 8 with Propshaft and cssbundling-rails (Sass + PostCSS) for styles. In production (Heroku), you must ensure the CSS bundle is built during slug compilation so Bootstrap styles are available.

Steps (based on Heroku + Rails docs):

1. Add buildpacks in this order (in Heroku Dashboard or via CLI):
   - heroku/nodejs
   - heroku/ruby
2. Ensure the following config vars are set (usually automatic):
   - RAILS_ENV=production
   - RAILS_LOG_TO_STDOUT=1
   - RAILS_SERVE_STATIC_FILES=1
3. The repository defines a `heroku-postbuild` script that builds the CSS bundle:
   - package.json -> scripts.heroku-postbuild: `yarn build:css`
   This runs during the Node buildpack phase and produces `app/assets/builds/application.css`.
4. During the Ruby buildpack phase, `rails assets:precompile` will run and pick up the compiled CSS because we add `app/assets/builds` to the asset path in `config/initializers/assets.rb`.
5. If you see missing styles in production, verify on the dyno:
   - The file `app/assets/builds/application.css` exists in the slug.
   - The layout includes `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` (already configured).
   - There are no Sass build errors in the Heroku build logs.

Notes:
- We intentionally ignore `app/assets/builds` in git; the file is built during deploy.
- If you cannot add the Node buildpack, a temporary workaround is to prebuild locally and commit the generated CSS (remove the ignore rule in `.gitignore`), but using the Node buildpack is the recommended approach.
