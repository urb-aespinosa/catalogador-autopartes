module Catalog
  # Decides in which markets each normalized application is sold (D19, D20):
  # one row per market, by evidence level, and a Validación row per part ×
  # make × model × market × level.
  #
  # - level a, "confirmado por ventas": MEX when INEGI has sales of that model
  #   in the same calendar year as the model year.
  # - level b, "según catálogo": only the catalog's own market (app.market).
  # - D20: a name vPIC lists in no year (vpic_unknown) enters only as MEX
  #   level a; its years without sales stay "Modelo-año · no encontrado".
  #
  # USA keeps level b for USA catalogs until EPA is wired in (Task 5).
  class MarketResolver
    INEGI_ORIGIN = "mercado MEX: ventas INEGI RAIAVL".freeze
    CATALOG_ORIGIN = "mercado según catálogo".freeze
    SALES = "confirmado por ventas".freeze
    CATALOG = "según catálogo".freeze

    def self.call(applications, inegi: InegiSales.default, epa: Epa.default) = new(inegi, epa).call(applications)

    def initialize(inegi, epa)
      @inegi = inegi
      @epa = epa
    end

    # -> [applications, validations]
    def call(applications)
      @levels = Hash.new { |h, k| h[k] = [] }
      @missing = Hash.new { |h, k| h[k] = [] }
      rows = applications.uniq.flat_map { resolve(_1) }
      [ rows.uniq, market_validations + missing_validations ]
    end

    private

    def resolve(app)
      return [ app ] if app.year.nil?

      sales = @inegi.sales(make: app.manufacturer, model: app.model, year: app.year)
      return unknown_name(app, sales) if app.vpic_unknown

      rows = []
      rows << mex_row(app, sales) if sales.any? || app.market == "MEX"
      rows << catalog_row(app, "USA") if app.market == "USA"
      rows
    end

    def unknown_name(app, sales)
      return [ mex_row(app, sales) ] if sales.any?

      @missing[[ app.manufacturer, app.model, app.url ]] << app.year
      []
    end

    def mex_row(app, sales)
      return catalog_row(app, "MEX") if sales.empty?

      record(app, "MEX", SALES)
      evidence = sales.map { |model, units| [ INEGI_ORIGIN, InegiSales::SOURCE_URL, "#{model} · #{app.year} · #{units} unidades" ] }
      app.with(market: "MEX", vpic_unknown: nil, evidence_urls: app.evidence_urls.to_a + evidence)
    end

    def catalog_row(app, market)
      record(app, market, CATALOG)
      app.with(market: market, vpic_unknown: nil, evidence_urls: app.evidence_urls.to_a + [ [ CATALOG_ORIGIN, app.url ] ])
    end

    def record(app, market, level)
      @levels[[ market, level, app.manufacturer, app.model ]] << [ app.year, app.url ]
    end

    def market_validations
      @levels.map do |(market, level, make, model), entries|
        Records::Validation.new(
          field: "Mercado", erp_value: nil, url: entries.map(&:last).compact.min,
          source_value: "#{market} · #{make} #{model} #{Vpic.year_ranges(entries.map(&:first).uniq)}", status: level
        )
      end
    end

    # Same text Vpic.expand used before D20.
    def missing_validations
      @missing.map do |(make, model, url), years|
        Records::Validation.new(field: "Modelo-año", erp_value: nil, source_value: "#{make} #{model} #{Vpic.year_ranges(years.uniq)}",
                                url: url, status: "no encontrado")
      end
    end
  end
end
