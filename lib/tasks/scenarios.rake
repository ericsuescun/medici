# Hand-testing scenarios: fixed data a person can walk through in a browser,
# with the expected outcome of every step printed beforehand. Development only —
# each one creates a staff account with the seed password.
#
#   bin/rails scenarios:self_report            # build or refresh, print the cheat sheet
#   RESET=1 bin/rails scenarios:self_report    # same, but wipe ALL its patients (hand-made ones too)
namespace :scenarios do
  desc "Build a fixed study for testing the public questionnaire by hand (RESET=1 wipes its patients)"
  task self_report: :environment do
    abort "scenarios:self_report is development-only (this is #{Rails.env})." unless Rails.env.development?

    require Rails.root.join("db/seeds/self_report_scenario")
    built = SelfReportScenario.build!(reset: ENV["RESET"].present?)
    puts SelfReportScenario.report(built)
  end
end
