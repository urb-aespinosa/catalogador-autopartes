module Catalog
  # Answers "was this vehicle sold new in Mexico that calendar year?" from the
  # versioned INEGI RAIAVL extract (D19). Our (make, model) names are mapped to
  # INEGI's (MARCA, MODELO) only through config/catalog/inegi_models.yml,
  # reviewed by the developer: an unmapped model never counts as "not sold",
  # it simply has no evidence.
  class InegiSales
    SOURCE_URL = "https://www.inegi.org.mx/datosprimarios/iavl/".freeze
    MODELS_PATH = Rails.root.join("config/catalog/inegi_models.yml")

    def self.default = @default ||= new(rows: default_rows, models: default_models)

    def self.default_rows = CSV.foreach(InegiSalesFilter::OUTPUT, headers: true).to_a

    def self.default_models = YAML.load_file(MODELS_PATH) || {}

    def initialize(rows:, models:)
      @totals = Hash.new(0)
      rows.each { |row| @totals[[ row["MARCA"], squish(row["MODELO"]), row["ANIO"].to_i ]] += row["UNI_VEH"].to_i }
      @models = models
    end

    # [[INEGI model, units], ...] with units > 0 in that calendar year, by model.
    def sales(make:, model:, year:)
      return [] if year.nil?

      targets(make, model).filter_map { |marca, modelo|
        units = @totals[[ marca, modelo, year ]]
        [ modelo, units ] if units.positive?
      }.sort
    end

    def mapped?(make:, model:) = targets(make, model).any?

    private

    def targets(make, model)
      Array(@models.dig(make, model)).map { [ _1.fetch("marca"), squish(_1.fetch("modelo")) ] }.uniq
    end

    def squish(name) = name.to_s.squish
  end
end
