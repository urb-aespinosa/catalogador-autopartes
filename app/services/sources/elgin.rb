module Sources
  # Elgin Industries engine catalog (USA market). Spec §5.2.
  #
  # 1. /part-autocomplete/?q=PART  → uuid (exact label match)
  # 2. /engine/part/UUID/          → specs + engine list (paginated with ?page=N)
  # 3. each engine page            → models, liters, CID, cylinders, fuels
  #
  # Years come per engine, not per model, so rows keep `years` as a range and
  # Catalog::Vpic expands them later (D8).
  class Elgin < Base
    BASE = "https://catalog.elginind.com".freeze
    MARKET = "USA".freeze

    def call(item:, hints:)
      uuid = find_uuid(item.part_number)
      return Result.not_found(market: MARKET) unless uuid

      part_url = "#{BASE}/engine/part/#{uuid}/"
      page = fetch_html(part_url)
      specs = read_specs(page, part_url)

      Result.found(
        market: MARKET,
        product_kind: product_kind(page),
        attributes: specs,
        applications: engine_rows(page, part_url).flat_map { engine_applications(_1) },
        per_engine_years: true
      )
    end

    private

    def find_uuid(part_number)
      url = "#{BASE}/part-autocomplete/?q=#{Catalog::Fetcher.encode_path(part_number)}"
      suggestions = Catalog::Fetcher.get_json(url)
      unless suggestions.is_a?(Array)
        raise ParseError.new(url: url, detail: "la búsqueda no devolvió una lista")
      end

      match = suggestions.find { _1.is_a?(Hash) && _1["label"] == part_number }
      match && match["value"]
    end

    # Spec table rows come as "Name | Value", units as a separate "Name UOM" row.
    def read_specs(page, url)
      rows = page.css("table").find { _1.text.include?("Specification Type") }
      raise ParseError.new(url: url, detail: "no se encontró la tabla de especificaciones") unless rows

      pairs = rows.css("tbody tr").to_h { |tr| tr.css("td").map { _1.text.strip }.first(2) }
      units = pairs.select { |name, _| name.end_with?(" UOM") }.transform_keys { _1.delete_suffix(" UOM") }
      pairs.except(*units.keys.map { "#{_1} UOM" }).map do |name, value|
        attribute(name: name, value: value, unit: units[name], url: url)
      end
    end

    def product_kind(page)
      description = page.css("li").map(&:text).find { _1.strip.start_with?("Description:") }
      :set if description&.match?(/Package of \d+/i)
    end

    # Follows the htmx "?page=N" rows until there are no more pages.
    def engine_rows(page, part_url)
      rows = []
      visited = Set[part_url]
      loop do
        page_rows = page.css("td[data-label='MFR']").map { engine_row(_1.parent, part_url) }
        raise ParseError.new(url: part_url, detail: "no se encontró la tabla de motores") if page_rows.empty?

        rows.concat(page_rows)
        next_url = page.at_css("tr[hx-get^='?page=']")&.[]("hx-get")&.then { "#{part_url}#{_1}" }
        break if next_url.nil? || !visited.add?(next_url)

        page = fetch_html(next_url)
      end
      rows
    end

    def engine_row(tr, url)
      year = tr.at_css("td[data-label='YEAR']")&.text&.strip
      link = tr.at_css("a[data-test='engine-details-link']")&.[]("href")
      raise ParseError.new(url: url, detail: "fila de motor sin enlace de detalle") unless link

      {
        manufacturer: tr.at_css("td[data-label='MFR']").text.strip,
        years: year_range(year, url),
        url: BASE + link
      }
    end

    # "1999–16" → 1999..2016 (the end shares the start's century unless it
    # wraps); "2008" → 2008..2008. Anything else is a layout change.
    def year_range(text, url)
      match = /\A(\d{4})(?:\s*[–-]\s*(\d{2}|\d{4}))?\z/.match(text.to_s.gsub("&ndash;", "–"))
      raise ParseError.new(url: url, detail: "año ilegible: #{text.inspect}") unless match

      start = match[1].to_i
      return start..start unless match[2]

      finish = match[2].length == 4 ? match[2].to_i : (start / 100 * 100) + match[2].to_i
      finish += 100 if finish < start
      start..finish
    end

    def engine_applications(engine)
      page = fetch_html(engine[:url])
      facts = engine_facts(page, engine[:url])

      facts[:models].product(facts[:fuels]).map do |model, fuel|
        application(
          manufacturer: engine[:manufacturer], model: model, years: engine[:years],
          liters: facts[:liters], cid: facts[:cid], cylinders: facts[:cylinders], fuel: fuel,
          market: MARKET, url: engine[:url],
          original: "#{engine[:manufacturer]} #{facts[:cid]}CID (#{facts[:liters]}L) #{engine[:years].first}-#{engine[:years].last}: #{model}"
        )
      end
    end

    def engine_facts(page, url)
      models = page.css("h2").find { _1.text.strip == "Models" }&.next_element&.text
      raise ParseError.new(url: url, detail: "no se encontró la lista de modelos") unless models

      labels = page.css("p.fw-semibold").to_h { [ _1.text.strip, _1.next_element&.text&.strip ] }
      fuels = labels["Fuel / Delivery"].to_s.split(" / ").first.to_s.split(",").map(&:strip)
      {
        models: models.split(",").map(&:strip).reject(&:empty?),
        liters: number(labels["Liters"])&.to_f,
        cid: number(labels["CID"])&.to_i,
        cylinders: number(labels["Cyl."])&.to_i,
        fuels: fuels.presence || [ nil ]
      }
    end

    # Elgin shows "-" for unknown values; those stay nil, never 0.
    def number(text)
      text if text.to_s.match?(/\A\d+(\.\d+)?\z/)
    end
  end
end
