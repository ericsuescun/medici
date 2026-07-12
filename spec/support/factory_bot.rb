RSpec.configure do |config|
  # Allow bare `create(...)` / `build(...)` in specs (existing specs may still
  # use the fully-qualified `FactoryBot.create(...)` — both work).
  config.include FactoryBot::Syntax::Methods
end
