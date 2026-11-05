module Sources
  # Rexite oil pumps (MEX market), read from its public WooCommerce Store API.
  # Spec §5.3. Years come per model ("Nissan 280Zx 1981"), so no vPIC step.
  class Rexite < Base
    SEARCH = "https://rexite.net/wp-json/wc/store/v1/products?search=%s".freeze
    MARKET = "MEX".freeze

    def call(item:, hints:)
      url = format(SEARCH, Catalog::Fetcher.encode_path(item.part_number))
      products = Catalog::Fetcher.get_json(url)
      raise ParseError.new(url: url, detail: "la búsqueda no devolvió una lista de productos") unless products.is_a?(Array)

      product = products.find { _1.is_a?(Hash) && _1["sku"] == item.part_number }
      return Result.not_found(market: MARKET) unless product

      Result.found(market: MARKET, applications: applications(product))
    end

    private

    def applications(product)
      terms = product.fetch("attributes", []).to_h { [ _1["name"], Array(_1["terms"]).map { |t| t["name"] } ] }
      compatible = terms["Compatible"].to_a
      raise ParseError.new(url: product["permalink"], detail: "el producto no trae compatibilidad") if compatible.empty?

      engine = engine_facts(terms)
      compatible.map do |entry|
        make, model, year = split_compatible(entry, terms, product["permalink"])
        application(
          manufacturer: make, model: model, year: year, **engine,
          market: MARKET, url: product["permalink"], original: entry
        )
      end
    end

    # "Nissan 280Zx 1981" → ["Nissan", "280ZX", 1981]. The model takes the
    # spelling of the product's own "Modelos" list when it is the same name.
    def split_compatible(entry, terms, url)
      make = terms["Marcas"].to_a.find { entry.start_with?("#{_1} ") }
      year = entry[/\b(\d{4})\z/, 1]
      raise ParseError.new(url: url, detail: "compatibilidad ilegible: #{entry.inspect}") unless make && year

      model = entry.delete_prefix("#{make} ").delete_suffix(" #{year}").strip
      model = terms["Modelos"].to_a.find { _1.casecmp?(model) } || model
      [ make, model, year.to_i ]
    end

    # "Motores" looks like "2.8L 6Cyl L"; the trailing L/V is the block layout.
    def engine_facts(terms)
      {
        liters: terms["Litros"]&.first&.to_f,
        cylinders: terms["Cilindros"]&.first&.to_i,
        block: terms["Motores"].to_a.first.to_s[/\s([LV])\z/, 1]
      }
    end
  end
end
