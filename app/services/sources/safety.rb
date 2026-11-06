module Sources
  # Safety Auto Parts legacy web catalog (USA market). Spec §5.4.
  #
  # There is no part-number search, so the adapter lists every engine of the
  # make groups that cover the ERP make and reads each engine's application
  # table, keeping the rows for the part's base number. Only the make narrows
  # the search; engine hints never do, so they cannot change the result (D1).
  #
  # Safety groups makes ("GM Trucks"), so each model's real make is identified
  # with NHTSA vPIC (D11). A model without an identified make produces no row.
  class Safety < Base
    BASE = "https://www.safetyautoparts.com/webcatalog".freeze
    MARKET = "USA".freeze
    MAKE_EVIDENCE = "identificación de marca NHTSA vPIC".freeze
    OVERSIZE = /\+(\d+)\z/
    GROUPS = YAML.load_file(Rails.root.join("config/catalog/makes.yml")).fetch("safety_groups").freeze

    def call(item:, hints:)
      base_number = item.part_number.sub(OVERSIZE, "")
      matches = find_rows(base_number, hints)
      return Result.not_found(market: MARKET) if matches.empty?

      applications, validations = build_applications(matches)
      Result.found(
        market: MARKET, applications: applications, validations: validations,
        attributes: oversize_attributes(item.part_number, matches.first[:url])
      )
    end

    private

    def find_rows(base_number, hints)
      group_codes(hints).flat_map { engines_for(_1) }.flat_map { rows_for(_1, base_number) }
    end

    def group_codes(hints)
      make = hints&.make && Catalog::Vpic.display_make(hints.make)
      codes = GROUPS.select { |_code, makes| makes.include?(make) }.keys
      codes.presence || GROUPS.keys
    end

    # tradengines.php answers with JavaScript: new Option('label','code').
    def engines_for(group)
      url = "#{BASE}/tradengines.php?MakeCode=#{group}"
      options = Catalog::Fetcher.get(url).body.scan(/new Option\('([^']*)','([^']*)'\)/)
      raise ParseError.new(url: url, detail: "la lista de motores está vacía") if options.empty?

      options.map { |label, code| { label: label, code: code, group: group } }
    end

    def rows_for(engine, base_number)
      url = "#{BASE}/tradappresults.php?EngineCode=#{Catalog::Fetcher.encode_path(engine[:code])}"
      fetch_html(url).css("tr").filter_map do |tr|
        cells = tr.css("td").map { _1.text.strip }
        next unless cells[1] == base_number

        { engine: engine, url: url, product: cells[0], applications: cells[2].to_s, note: cells[3] }
      end
    end

    APPLICATION = /(\d\d)-(\d\d) (.+?)(?=\s+\d\d-\d\d\s|\s*\z)/

    # "14-21 Silverado 1500 14-21 Sierra" → [["Silverado 1500", 2014..2021], ...]
    # The pieces must rebuild the whole cell; anything else is a layout change.
    def model_ranges(text, url)
      cell = text.squish
      pieces = cell.scan(APPLICATION)
      rebuilt = pieces.map { |from, to, model| "#{from}-#{to} #{model}" }.join(" ")
      raise ParseError.new(url: url, detail: "aplicación ilegible: #{cell.inspect}") if pieces.empty? || rebuilt != cell

      pieces.map do |from, to, model|
        [ model.strip, Catalog::DescriptionParser.expand_year(from)..Catalog::DescriptionParser.expand_year(to) ]
      end
    end

    def build_applications(matches)
      validations = []
      applications = matches.flat_map do |match|
        engine = engine_facts(match[:engine][:label])
        model_ranges(match[:applications], match[:url]).flat_map do |model, years|
          make, evidence = Catalog::Vpic.identify_make(model, candidates: GROUPS.fetch(match[:engine][:group]))
          unless make
            validations << unidentified_make(model, match[:url])
            next []
          end

          years.map do |year|
            application(
              manufacturer: make, model: model, year: year, **engine, market: MARKET, url: match[:url],
              original: "#{match[:product]} #{match[:applications]}".strip,
              evidence_urls: [ [ MAKE_EVIDENCE, evidence ] ]
            )
          end
        end
      end
      [ applications, validations.uniq ]
    end

    CYLINDER_COUNTS = (3..12)

    # "4.3L 262 LV3 OHV 12V V6 14-27 SIERRA SILVERADO". Engine codes such as
    # "L86" share the layout shape, so the layout is the last L/V token with a
    # real cylinder count.
    def engine_facts(label)
      layout = label.scan(/\b([LV])(\d{1,2})\b/).reverse.find { CYLINDER_COUNTS.cover?(_2.to_i) }
      {
        liters: label[/\A(\d+\.\d)L\b/, 1]&.to_f,
        cid: label[/\A\d+\.\dL (\d{3})\b/, 1]&.to_i,
        cylinders: layout && layout[1].to_i,
        block: layout && layout[0]
      }
    end

    def unidentified_make(model, url)
      Catalog::Records::Validation.new(field: "Fabricante", erp_value: nil, source_value: model, url: url, status: "no encontrado")
    end

    # D10: the oversize comes from the part number itself ("+20" = 0.020").
    def oversize_attributes(part_number, url)
      designation = part_number[OVERSIZE]
      return [] unless designation

      [ attribute(name: "Sobremedida", value: designation, original: designation, url: url, origin: "número de parte") ]
    end
  end
end
