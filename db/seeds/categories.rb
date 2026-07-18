# Idempotent seeder for the study categories (therapeutic areas). Reference
# data required for the study form's category dropdown, the public home-page
# filter, and the navbar search — safe for every environment, like
# RolesAndPermissionsSeeder. Re-running never duplicates or renames anything
# (staff-added categories are left untouched).
#
# The list follows the therapeutic-area taxonomy used in clinical-trial
# registries (ClinicalTrials.gov browse conditions / MSD-style specialty
# areas), in Spanish, since the platform is Spanish-first.
module CategoriesSeeder
  NAMES = [
    "Cardiología",
    "Dermatología",
    "Endocrinología y diabetes",
    "Enfermedades infecciosas",
    "Gastroenterología",
    "Geriatría",
    "Ginecología y obstetricia",
    "Hematología",
    "Inmunología y alergias",
    "Nefrología",
    "Neumología",
    "Neurología",
    "Nutrición y metabolismo",
    "Oftalmología",
    "Oncología",
    "Ortopedia y traumatología",
    "Otorrinolaringología",
    "Pediatría",
    "Psiquiatría y salud mental",
    "Reumatología",
    "Urología",
    "Vacunas"
  ].freeze

  def self.seed!
    NAMES.each { |name| Category.find_or_create_by!(name: name) }
  end
end
