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
  # - USA level a, "confirmado por EPA": EPA lists the model that year and,
  #   when the application has an engine, a configuration with that engine
  #   (liters to one decimal and cylinders).
  # - Engine refuted by EPA (D19, D22: only where EPA's coverage is complete):
  #   USA catalog → the application is removed in every market; MEX catalog →
  #   MEX stays and there is no USA row. Either way Validación "Motor · difiere".
  class MarketResolver
    INEGI_ORIGIN = "mercado MEX: ventas INEGI RAIAVL".freeze
    EPA_ORIGIN = "mercado USA: EPA fueleconomy.gov".freeze
    CATALOG_ORIGIN = "mercado según catálogo".freeze
    SALES = "confirmado por ventas".freeze
    EPA = "confirmado por EPA".freeze
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
      @engine_validations = []
      rows = applications.uniq.flat_map { resolve(_1) }
      [ rows.uniq, market_validations + missing_validations + @engine_validations ]
    end

    private

    def resolve(app)
      return [ app ] if app.year.nil?

      sales = @inegi.sales(make: app.manufacturer, model: app.model, year: app.year)
      return unknown_name(app, sales) if app.vpic_unknown

      configs = @epa&.configurations(make: app.manufacturer, model: app.model, year: app.year)
      matches = configs && engine_matches(app, configs)
      if matches&.empty?
        if refutes?(app)
          record_engine_mismatch(app, configs, app.market == "USA" ? "eliminada" : "se conserva solo MEX")
          return refuted(app, sales)
        end

        record_engine_mismatch(app, configs, kept_outcome(app))
        matches = configs = nil # D22: the mismatch neither confirms nor removes
      end

      rows = []
      rows << mex_row(app, sales) if sales.any? || app.market == "MEX"
      rows << usa_row(app, configs, matches) if configs || app.market == "USA"
      rows
    end

    # USA catalog: the source's own engine is wrong, so no market keeps it.
    # MEX catalog: EPA only speaks for the USA market.
    def refuted(app, sales) = app.market == "USA" ? [] : [ mex_row(app, sales) ]

    # nil when the application has no engine to compare (EPA presence is enough).
    def engine_matches(app, configs)
      return nil if app.liters.blank? || app.cylinders.blank?

      configs.select { _1.displ.round(1) == app.liters.to_f.round(1) && _1.cylinders == app.cylinders.to_i }
    end

    def refutes?(app)
      @epa.refutes?(make: app.manufacturer, model: app.model, year: app.year, liters: app.liters, cylinders: app.cylinders)
    end

    def usa_row(app, configs, matches)
      return catalog_row(app, "USA") unless configs

      record(app, "USA", EPA)
      url = @epa.evidence_url(make: app.manufacturer, year: app.year, configurations: matches.presence || configs)
      app.with(market: "USA", vpic_unknown: nil, evidence_urls: app.evidence_urls.to_a + [ [ EPA_ORIGIN, url ] ])
    end

    def kept_outcome(app)
      @epa.confirm_only?(make: app.manufacturer, model: app.model) ? "se conserva (confirm_only)" : "se conserva (excepción revisada)"
    end

    # The outcome tells an auditor what happened to the row (D22).
    def record_engine_mismatch(app, configs, outcome)
      epa_engines = configs.map { "#{_1.displ}L #{_1.cylinders} cil" }.uniq.join(", ")
      url = @epa.evidence_url(make: app.manufacturer, year: app.year, configurations: configs)
      @engine_validations << Records::Validation.new(
        field: "Motor", erp_value: nil, url: app.url, status: "difiere",
        source_value: "#{app.manufacturer} #{app.model} #{app.year} #{app.liters}L #{app.cylinders} cil · EPA: #{epa_engines} · #{url} · #{outcome}"
      )
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
