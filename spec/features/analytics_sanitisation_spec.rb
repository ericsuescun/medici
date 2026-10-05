require "rails_helper"

# What actually reaches Google. The request specs in
# spec/requests/analytics_tags_spec.rb guard WHERE the tags render; this guards
# WHAT they send once they do, which only a browser can show: gtag() is a stub
# that pushes its arguments onto window.dataLayer, so reading that array back is
# reading the exact payloads Google would get. A study page titles itself
# "<public_title> — Medici" and lives at /studies/:id/about, and neither the
# title nor the id may ever appear in any of them.
RSpec.feature "Measurement tags never name a study", type: :feature, js: true do
  around do |example|
    # Same hand-rolled ENV handling as analytics_tags_spec.rb — no ClimateControl
    # here. Capybara's Puma runs in-process, so the app sees these values.
    keys = %w[GA4_MEASUREMENT_ID META_PIXEL_ID ANALYTICS_ENABLED]
    original = ENV.to_hash.slice(*keys)
    ENV["GA4_MEASUREMENT_ID"] = "G-TESTID"
    ENV.delete("META_PIXEL_ID")
    ENV["ANALYTICS_ENABLED"] = "true"
    example.run
  ensure
    keys.each { |k| ENV.delete(k) }
    original.each { |k, v| ENV[k] = v }
  end

  let(:study) { create(:study, public_title: "Zebra Protocolo XYZ") }

  # Must match the controller's STORAGE_KEY; with the decision pre-seeded the
  # banner never shows and the controller reports straight from connect().
  STORAGE_KEY = "medici.analytics.consent".freeze

  # gtag() stores `arguments` objects; JSON-encode in the browser so every entry
  # comes back as a plain array (or a plain object for anything gtag.js itself
  # may push) rather than whatever the WebDriver serialiser makes of them.
  DATA_LAYER = <<~JS.freeze
    JSON.stringify((window.dataLayer || []).map((entry) => {
      const args = Array.prototype.slice.call(entry);
      return args.length ? args : entry;
    }))
  JS

  def data_layer
    JSON.parse(page.evaluate_script(DATA_LAYER))
  end

  def page_views(entries)
    entries.select { |e| e.is_a?(Array) && e[0] == "event" && e[1] == "page_view" }
  end

  # Stimulus connects after the document loads; poll instead of asserting on
  # the first read, the same race the participation feature spec documents.
  def wait_for_page_view
    deadline = Time.current + Capybara.default_max_wait_time
    loop do
      entries = data_layer
      return entries if page_views(entries).any?
      raise "no page_view reached window.dataLayer: #{entries.inspect}" if Time.current > deadline

      sleep 0.1
    end
  end

  scenario "a consented visit to a study page reaches dataLayer with the study stripped out" do
    # localStorage is per-origin, so the decision has to be seeded from a page on
    # the app's own origin before the study page is visited.
    visit root_path
    page.execute_script("window.localStorage.setItem(#{STORAGE_KEY.to_json}, 'granted')")

    visit study_about_path(study)
    expect(page).to have_css("body[data-controller='analytics']")
    expect(page).to have_content("Zebra Protocolo XYZ") # the page itself still names it

    entries = wait_for_page_view
    payloads = entries.map(&:to_json)

    expect(payloads).not_to include(a_string_including("Zebra Protocolo XYZ"))
    expect(payloads).not_to include(a_string_including("/studies/#{study.id}"))

    view = page_views(entries).find { |e| e[2].is_a?(Hash) && e[2]["page_location"].to_s.end_with?("/studies/detail") }
    expect(view).not_to be_nil, "expected a page_view with page_location ending in /studies/detail, got #{page_views(entries).inspect}"
    expect(view[2]["page_title"]).to eq("Medici")

    # The config call persists its params onto every later event, including the
    # ones gtag fires by itself — so it has to carry the sanitised pair too.
    config = entries.find { |e| e.is_a?(Array) && e[0] == "config" && e[1] == "G-TESTID" }
    expect(config).not_to be_nil
    expect(config[2]).to include("send_page_view" => false, "page_title" => "Medici")
    expect(config[2]["page_location"]).to end_with("/studies/detail")
  end

  scenario "the ¡Quiero participar! click carries the sanitised page, not the real one" do
    visit root_path
    page.execute_script("window.localStorage.setItem(#{STORAGE_KEY.to_json}, 'granted')")

    visit study_about_path(study)
    wait_for_page_view
    find("a[data-analytics-name-param='click_participate']", match: :first).click

    expect(page).to have_current_path(new_participation_request_path(study_id: study.id))
    # The click is reported before Turbo leaves the page; the next page carries
    # no tags at all, so dataLayer is whatever the study page left behind — but
    # Turbo keeps the document, so the array survives the visit.
    entries = data_layer
    click = entries.find { |e| e.is_a?(Array) && e[0] == "event" && e[1] == "click_participate" }
    expect(click).not_to be_nil, "click_participate never reached dataLayer: #{entries.inspect}"
    expect(click[2]["page_location"]).to end_with("/studies/detail")
    expect(click[2]["page_title"]).to eq("Medici")
    expect(entries.map(&:to_json)).not_to include(a_string_including("Zebra Protocolo XYZ"))
  end
end
