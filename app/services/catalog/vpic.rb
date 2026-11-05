module Catalog
  # NHTSA vPIC, used for exactly two things (spec §5.7):
  #
  # 1. expand: per-engine year ranges (Elgin) become one row per confirmed
  #    model-year (D8). vPIC confirms model + year, not engine (D11).
  # 2. identify_make: which make owns a model when a source groups makes
  #    (Safety "GM Trucks") (D11).
  #
  # Responses go through Fetcher, so they are cached like any other source.
  module Vpic
    BASE = "https://vpic.nhtsa.dot.gov/api/vehicles".freeze
    EVIDENCE = "verificación NHTSA vPIC".freeze
    MAKES = YAML.load_file(Rails.root.join("config/catalog/makes.yml")).fetch("display").freeze
    ALIASES = YAML.load_file(Rails.root.join("config/catalog/vpic_aliases.yml")).freeze

    module_function

    # -> [applications, validations]
    def expand(applications)
      rows = []
      validations = []
      applications.each do |app|
        next rows << app unless app.years && app.market == "USA"

        confirmed, missing = app.years.partition { |year| confirmed?(app, year) }
        rows.concat(confirmed.map { |year| confirmed_row(app, year) })
        validations << missing_validation(app, missing) if missing.any?
      end
      [ rows, validations.uniq ]
    end

    # -> [make, evidence_url] or [nil, nil] when no single candidate has the model.
    def identify_make(model, candidates:)
      owners = candidates.filter_map do |make|
        url = "#{BASE}/GetModelsForMake/#{Fetcher.encode_path(make)}?format=json"
        [ make, url ] if model_names(url).any? { same_model?(model, _1) }
      end
      owners.one? ? owners.first : [ nil, nil ]
    end

    # Spec §5.7: names match ignoring only case, spaces and hyphens. Trims and
    # market names vPIC does not list ("Silverado 1500 HD Classic",
    # "Express Pasajeros") are not confirmed; they go to Validación.
    def same_model?(source_name, vpic_name)
      squash(source_name) == squash(vpic_name) && squash(source_name).present?
    end

    def squash(name) = name.to_s.upcase.delete(" -")

    def display_make(make) = MAKES.fetch(make.to_s.upcase, make.to_s)

    def year_url(make, year)
      "#{BASE}/GetModelsForMakeYear/make/#{Fetcher.encode_path(display_make(make))}/modelyear/#{year}?format=json"
    end

    # The capacity alias (D14) only changes the name sent to vPIC.
    def confirmed?(app, year)
      name = ALIASES.dig(display_make(app.manufacturer), app.model) || app.model
      model_names(year_url(app.manufacturer, year)).any? { same_model?(name, _1) }
    end

    def confirmed_row(app, year)
      app.with(year: year, years: nil, evidence_urls: app.evidence_urls.to_a + [ [ EVIDENCE, year_url(app.manufacturer, year) ] ])
    end

    def missing_validation(app, years)
      Records::Validation.new(
        field: "Modelo-año", erp_value: nil,
        source_value: "#{display_make(app.manufacturer)} #{app.model} #{year_ranges(years)}",
        url: app.url, status: "no encontrado"
      )
    end

    # [2008, 2009, 2010, 2015] → "2008-2010, 2015"
    def year_ranges(years)
      years.sort.slice_when { |a, b| b != a + 1 }.map { _1.size == 1 ? _1.first.to_s : "#{_1.first}-#{_1.last}" }.join(", ")
    end

    def model_names(url)
      results = Fetcher.get_json(url)
      results = results["Results"] if results.is_a?(Hash)
      raise Sources::ParseError.new(url: url, detail: "respuesta de vPIC sin Results") unless results.is_a?(Array)

      results.filter_map { _1["Model_Name"] if _1.is_a?(Hash) }
    end
  end
end
