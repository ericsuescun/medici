require "rails_helper"

RSpec.describe "Política de tratamiento de datos", type: :request do
  it "is public — no login, which is the whole point" do
    get data_policy_path

    expect(response).to be_successful
    expect(response.body).to include("Política de Tratamiento de Datos Personales")
  end

  # Decreto 1074 de 2015, Art. 2.2.2.25.3.1 (Decreto 1377 de 2013, Art. 13) lists
  # six minimum contents. A policy missing one of them is not a policy, so each
  # gets an assertion rather than one blanket "renders" test.
  describe "the six contents Decreto 1074 requires" do
    before { get data_policy_path }

    it "1. identifies the responsable, with every contact field" do
      expect(response.body).to include("Razón social", "NIT", "Domicilio", "Dirección",
                                       "Correo electrónico", "Teléfono")
    end

    it "2. states the treatment and its purposes" do
      expect(response.body).to include("Para qué usamos sus datos")
      expect(response.body).to include("No vendemos sus datos")
    end

    it "3. lists the rights of the titular (Ley 1581, Art. 8)" do
      expect(response.body).to include("Sus derechos como titular")
      expect(response.body).to include("Conocer, actualizar y rectificar")
      expect(response.body).to include("Revocar la autorización")
      expect(response.body).to include("Superintendencia de Industria y Comercio")
    end

    it "4. names the area that answers peticiones, consultas y reclamos" do
      expect(response.body).to include("Área responsable")
    end

    it "5. gives the procedure, with the statutory deadlines" do
      expect(response.body).to include("diez (10) días hábiles")   # consultas, Art. 14
      expect(response.body).to include("cinco (5) días hábiles")   # its extension
      expect(response.body).to include("quince (15) días hábiles") # reclamos, Art. 15
      expect(response.body).to include("ocho (8) días hábiles")    # its extension
    end

    it "6. states the effective date and the validity of the database" do
      expect(response.body).to include("Fecha de entrada en vigencia")
      expect(response.body).to include("Período de vigencia de la base de datos")
    end
  end

  # Decreto 1377, Art. 15: when sensitive data is collected the notice must say
  # answering is optional. Health data is sensitive (Ley 1581, Art. 5).
  it "says outright that answering questions about sensitive data is optional" do
    get data_policy_path

    expect(response.body).to include("no está obligado a autorizar el tratamiento de datos sensibles")
  end

  describe "when the legal identity has not been configured" do
    # dotenv-rails loads a local .env in test too, so a developer who has set the
    # MEDICI_* vars for their own machine would otherwise see this example fail.
    # Clear them explicitly for the example's duration and put them back after.
    around do |example|
      keys = %w[MEDICI_LEGAL_NAME MEDICI_NIT MEDICI_CITY MEDICI_ADDRESS MEDICI_PRIVACY_EMAIL MEDICI_PHONE]
      original = ENV.to_hash.slice(*keys)
      keys.each { |k| ENV.delete(k) }
      example.run
    ensure
      original.each { |k, v| ENV[k] = v }
    end

    it "marks the missing fields and warns the reader" do
      get data_policy_path

      expect(DataPolicy).not_to be_complete
      expect(response.body).to include("policy-pending")
      expect(response.body).to include("Documento en preparación")
    end
  end

  describe "when it has" do
    around do |example|
      vars = {
        "MEDICI_LEGAL_NAME" => "Medici SAS", "MEDICI_NIT" => "900.000.000-1",
        "MEDICI_CITY" => "Bogotá D.C.", "MEDICI_ADDRESS" => "Calle 1 # 2-3",
        "MEDICI_PRIVACY_EMAIL" => "datos@medici.co", "MEDICI_PHONE" => "+57 300 000 0000"
      }
      vars.each { |k, v| ENV[k] = v }
      example.run
    ensure
      vars.each_key { |k| ENV.delete(k) }
    end

    it "shows the real identity and drops the warning" do
      get data_policy_path

      expect(DataPolicy).to be_complete
      expect(response.body).to include("Medici SAS", "900.000.000-1", "datos@medici.co")
      expect(response.body).not_to include("policy-pending")
      expect(response.body).not_to include("Documento en preparación")
    end
  end

  describe "the links that point here" do
    it "is offered from the participation form, next to the authorization" do
      study = FactoryBot.create(:study)

      get new_participation_request_path(study_id: study.id)

      expect(response.body).to include(data_policy_path)
    end

    it "is listed in the sitemap" do
      get sitemap_path

      expect(response.body).to include("#{data_policy_path}</loc>")
    end
  end

  # The page explaining our data handling is the last place to load an ad pixel.
  it "carries no measurement tags itself" do
    ENV["GA4_MEASUREMENT_ID"] = "G-TESTID"
    ENV["ANALYTICS_ENABLED"] = "true"

    get data_policy_path

    expect(response.body).not_to include("googletagmanager")
    expect(response.body).not_to include('data-controller="analytics"')
  ensure
    ENV.delete("GA4_MEASUREMENT_ID")
    ENV.delete("ANALYTICS_ENABLED")
  end
end
