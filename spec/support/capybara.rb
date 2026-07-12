require 'capybara/rails'
require 'capybara/rspec'

# Headless Chrome for JS-driven specs. selenium-manager (bundled with
# selenium-webdriver 4.x) auto-downloads a matching chromedriver, so no
# system chromedriver or webdrivers gem is needed.
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

# Non-JS feature specs run under fast rack_test; `js: true` switches to Chrome.
Capybara.default_driver    = :rack_test
Capybara.javascript_driver = :headless_chrome

# Quiet the Puma server that boots for `js: true` specs.
Capybara.server = :puma, { Silent: true }

# Turbo/Stimulus interactions can exceed the 2s default; give browser specs headroom.
Capybara.default_max_wait_time = 5
