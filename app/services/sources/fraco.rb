require "open3"

module Sources
  # Fraco gasket sets (MEX market): one PDF spec sheet per part. Spec §5.1.
  #
  # The model/years table is read by word position (pdftotext -bbox), because
  # the plain text mixes columns. Engine data comes from the sheet's summary
  # box ("2,488 c.c.", "Ø cilindro 89 mm", ...). No AI at runtime.
  class Fraco < Base
    URL = "https://www.fraco.com.mx/QRMX/%s.pdf".freeze
    MARKET = "MEX".freeze
    MODEL_COLUMN = (60.0..195.0)
    YEARS_COLUMN = (240.0..285.0)
    SAME_LINE = 4.0 # points between a model line and its years
    MAKES = YAML.load_file(Rails.root.join("config/catalog/makes.yml")).fetch("display").keys.freeze

    def call(item:, hints:)
      url = format(URL, Catalog::Fetcher.encode_path(item.part_number))
      pdf = Catalog::Fetcher.get(url).body
      text = pdftotext(pdf, "-layout", url)
      engine = engine_data(text, url)

      Result.found(
        market: MARKET,
        applications: model_years(pdftotext(pdf, "-bbox", url), url).map do |model, year, original|
          application(**engine, model: model, year: year, market: MARKET, url: url, original: original)
        end,
        attributes: attributes(text, url)
      )
    rescue Catalog::Fetcher::SourceError => e
      raise unless e.status == 404

      Result.not_found(market: MARKET)
    end

    private

    def pdftotext(pdf, mode, url)
      Tempfile.create([ "fraco", ".pdf" ], binmode: true) do |file|
        file.write(pdf)
        file.flush
        output, _errors, status = Open3.capture3("pdftotext", mode, file.path, "-")
        raise ParseError.new(url: url, detail: "pdftotext no pudo leer el PDF") unless status.success?

        output
      end
    end

    # -> [[model, year, original_text], ...]
    def model_years(bbox_xml, url)
      words = Nokogiri::XML(bbox_xml).css("word").map do |w|
        { x: w["xMin"].to_f, y: w["yMin"].to_f, text: w.text.strip }
      end
      top = words.find { _1[:text] == "MODELO" }&.dig(:y)
      raise ParseError.new(url: url, detail: "no se encontró la columna MODELO") unless top

      bottom = words.find { _1[:text] == "MLO:" }&.dig(:y) || Float::INFINITY
      region = words.select { _1[:y] > top + 5 && _1[:y] < bottom }
      years = region.select { YEARS_COLUMN.cover?(_1[:x]) && _1[:text].match?(%r{\A\d{2}/\d{2},?\z}) }

      rows = model_lines(region).filter_map do |line|
        year_word = years.find { (_1[:y] - line[:y]).abs <= SAME_LINE }
        next unless year_word

        range = year_range(year_word[:text])
        line[:text].split(",").map(&:strip).reject(&:empty?).product(range.to_a).map do |model, year|
          [ model, year, "#{line[:text]} #{year_word[:text]}" ]
        end
      end.flatten(1)
      raise ParseError.new(url: url, detail: "la tabla de modelos y años está vacía") if rows.empty?

      rows
    end

    # Groups model-column words into lines by vertical position.
    def model_lines(region)
      region.select { MODEL_COLUMN.cover?(_1[:x]) }.sort_by { [ _1[:y], _1[:x] ] }
        .slice_when { |a, b| (b[:y] - a[:y]).abs > 2.5 }
        .map { |words| { y: words.first[:y], text: words.sort_by { _1[:x] }.map { _1[:text] }.join(" ") } }
    end

    def year_range(text)
      from, to = text.delete(",").split("/").map { Catalog::DescriptionParser.expand_year(_1) }
      from..to
    end

    def engine_data(text, url)
      cylinders = text[/\b[LV](\d{1,2})\b/, 1]
      raise ParseError.new(url: url, detail: "no se encontraron datos de motor") unless cylinders

      {
        manufacturer: MAKES.find { text.match?(/\b#{Regexp.escape(_1)}\b/) },
        liters: text[/\b(\d\.\d)\s?L\b/, 1]&.to_f,
        cc: text[/([\d.,]+)\s*c\.c\./, 1]&.delete(".,")&.to_i,
        cid: text[/(\d+)\s*pulg/, 1]&.to_i,
        cylinders: cylinders.to_i,
        block: text[/\b([LV])\d{1,2}\b/, 1]
      }
    end

    def attributes(text, url)
      {
        "Número de válvulas" => [ text[/\b(\d{1,2})V\b/, 1], nil ],
        "Diámetro" => [ text[/Ø cilindro (\d+(?:\.\d+)?) mm/, 1], "mm" ],
        "Carrera" => [ text[/Carrera (\d+(?:\.\d+)?) mm/, 1], "mm" ],
        "Junta Cabeza" => [ text[/HGX-[\w]+-(MLO|SB)\b/, 1], nil ]
      }.filter_map do |name, (value, unit)|
        attribute(name: name, value: value, unit: unit, url: url) if value
      end
    end
  end
end
