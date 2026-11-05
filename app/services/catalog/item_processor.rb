module Catalog
  # Processes one part end to end and stores the result in SourceItem#result:
  #
  #   parse hints → official adapter → vPIC expansion (per-engine years only)
  #   → complements from officially confirmed interchanges → normalize
  #   → reconcile hints vs. source (Validación)
  #
  # It never raises for source problems: a failed request or an unreadable
  # page becomes an "error de fuente" row and the run continues (spec §6.7).
  class ItemProcessor
    INTERCHANGES = YAML.load_file(Rails.root.join("config/catalog/interchanges.yml")).freeze
    SOURCE_ERRORS = [ Fetcher::SourceError, Sources::ParseError ].freeze

    def self.call(item) = new(item).call

    def initialize(item, interchanges: INTERCHANGES, adapters: {})
      @item = item
      @interchanges = interchanges.select { _1["part"] == item.part_number }
      @adapters = adapters
      @validations = []
      @status = "done"
    end

    def call
      @item.update!(status: "fetching")
      hints = DescriptionParser.call(@item.description)
      result = official_result(hints)
      result = add_complements(result, hints) if result

      normalized = Normalizer.call(item: @item, result: result)
      final = normalized.with(validations: @validations + normalized.validations + Reconciler.call(item: @item, hints: hints, result: normalized))
      @item.update!(status: @status, product: final.product, result: final.to_h)
      final
    end

    private

    def official_result(hints)
      adapter = Sources::Registry.for(@item.manufacturer)
      return not_found(@item.manufacturer, nil) unless adapter

      result = adapter.call(item: @item, hints: hints)
      return not_found(@item.manufacturer, nil) unless result.status == :found

      expand_years(result)
    rescue *SOURCE_ERRORS => e
      source_error(e)
    end

    def expand_years(result)
      return result unless result.per_engine_years

      applications, validations = Vpic.expand(result.applications)
      result.with(applications: applications, validations: result.validations + validations)
    end

    # D11: only interchanges confirmed by an official source complement the
    # part, and only with applications (never another part's attributes).
    def add_complements(result, hints)
      @interchanges.reduce(result) do |current, entry|
        complement = complement_applications(entry, hints)
        current.with(
          applications: current.applications + complement,
          interchanges: current.interchanges + [ confirmed_interchange(entry) ]
        )
      end
    end

    def complement_applications(entry, hints)
      adapter = (@adapters[entry["adapter"]] || "Sources::#{entry['adapter']}".constantize).new
      other = SourceItem.new(part_number: entry["number"], manufacturer: entry["brand"])
      found = expand_years(adapter.call(item: other, hints: hints))
      return [] unless found.status == :found

      origin = "vía intercambio de #{entry['number']} (#{entry['brand']})"
      found.applications.map { _1.with(origin: origin) }
    rescue *SOURCE_ERRORS => e
      source_error(e)
      []
    end

    def confirmed_interchange(entry)
      Records::Interchange.new(number: entry["number"], brand: entry["brand"], kind: nil, url: entry["url"], origin: "oficial")
    end

    def not_found(manufacturer, url)
      @status = "not_found"
      @validations << Records::Validation.new(field: "Fuente", erp_value: manufacturer, source_value: nil, url: url, status: "no encontrado")
      nil
    end

    def source_error(error)
      @status = "error"
      @validations << Records::Validation.new(field: "Fuente", erp_value: @item.manufacturer, source_value: error.detail, url: error.url, status: "error de fuente")
      nil
    end
  end
end
