module Catalog
  # EPA fueleconomy.gov configurations from the versioned bulk extract (D19):
  # which engines (displacement, cylinders) and fuels EPA lists for a model in
  # a model year. Our (make, model) names are mapped to EPA's own model names
  # only through config/catalog/epa_models.yml, reviewed by the developer.
  class Epa
    Configuration = Data.define(:id, :model, :displ, :cylinders, :fuel_key)

    MODELS_PATH = Rails.root.join("config/catalog/epa_models.yml")
    OPTIONS_URL = "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options".freeze

    def self.default
      @default ||= new(rows: default_rows, models: default_models, confirm_only: default_confirm_only,
                       confirm_only_years: default_confirm_only_years)
    end

    def self.default_rows = CSV.foreach(EpaVehiclesFilter::OUTPUT, headers: true).to_a

    # The YAML reuses identical lists through anchors (&silverado / *silverado).
    def self.config = YAML.load_file(MODELS_PATH, aliases: true) || {}

    def self.default_models = config.fetch("models", {})

    def self.default_confirm_only = config.fetch("confirm_only", {})

    def self.default_confirm_only_years = config.fetch("confirm_only_years", [])

    def initialize(rows:, models:, confirm_only: {}, confirm_only_years: [])
      @index = rows.group_by { [ _1["make"], _1["model"], _1["year"].to_i ] }
                   .transform_values { |group| group.map { configuration(_1) } }
      @models = models
      @confirm_only = confirm_only.flat_map { |make, list| list.map { [ make, _1 ] } }.to_set
      @confirm_only_years = confirm_only_years.map { exception_key(_1.fetch("make"), _1.fetch("model"), _1.fetch("year"), _1.fetch("liters"), _1.fetch("cylinders")) }.to_set
    end

    # D22: EPA may refute an engine only where its coverage of that line is
    # complete. confirm_only models (2500/3500/HD names, generic names of lines
    # with HD versions EPA does not rate) and reviewed gaps (model · year ·
    # engine) only confirm: a mismatch keeps the row and goes to Validación as
    # "difiere".
    def refutes?(make:, model:, year:, liters:, cylinders:)
      @models.dig(make, model).present? &&
        !confirm_only?(make: make, model: model) &&
        !@confirm_only_years.include?(exception_key(make, model, year, liters, cylinders))
    end

    def confirm_only?(make:, model:) = @confirm_only.include?([ make, model ])

    # nil = no evidence either way: the model is not mapped, or EPA lists none
    # of its equivalent models that year (e.g. heavy-duty pickups).
    def configurations(make:, model:, year:)
      return nil if year.nil?

      found = Array(@models.dig(make, model)).flat_map { @index.fetch([ make, _1, year ], []) }
      found.empty? ? nil : found.sort_by(&:id)
    end

    def options_url(make:, year:, epa_model:)
      "#{OPTIONS_URL}?year=#{year}&make=#{Fetcher.encode_path(make)}&model=#{Fetcher.encode_path(epa_model)}"
    end

    def evidence_url(make:, year:, configurations:)
      options_url(make: make, year: year, epa_model: configurations.first.model)
    end

    private

    # Same engine rule as the refutation: liters to one decimal, cylinders.
    def exception_key(make, model, year, liters, cylinders) = [ make, model, year.to_i, liters.to_f.round(1), cylinders.to_i ]

    def configuration(row)
      fuel = row["atvType"].present? ? "#{row["fuelType"]} (#{row["atvType"]})" : row["fuelType"]
      Configuration.new(id: row["id"].to_i, model: row["model"], displ: row["displ"].to_f,
                        cylinders: row["cylinders"].to_i, fuel_key: fuel)
    end
  end
end
