# `shown` ("Mostrado") was added in 2025 and never read by any code — it was a
# checkbox in the form and a column in the tables, and nothing else. It becomes
# the switch that keeps a SPECIFIC question off the public questionnaire, so
# the centre asks it instead (by phone or in consultation) and records the
# answer itself. Basic questions are always asked online; the model enforces it.
#
# Every row is reset to true on the way: the old values meant nothing, and a
# `false` left over from somebody unticking "Mostrado" must not silently pull a
# question off the questionnaire the day this ships.
class RenameShownToAskedOnlineOnCriteriaVariables < ActiveRecord::Migration[8.0]
  def up
    rename_column :criteria_variables, :shown, :asked_online
    execute "UPDATE criteria_variables SET asked_online = TRUE"
  end

  def down
    rename_column :criteria_variables, :asked_online, :shown
  end
end
