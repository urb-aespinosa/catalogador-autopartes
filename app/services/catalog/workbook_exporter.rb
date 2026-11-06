module Catalog
  # Writes the delivered workbook (spec §6.5): the six sheets of the evaluator
  # example with identical names and columns, plus Fuentes and Validación.
  # Every sheet has a total, stable row order so two runs give the same content.
  class WorkbookExporter
    TITLE = "Catálogo Bonaparte - Refaccionaria Trópico de Cáncer".freeze
    CATEGORY = "Vehículo ligero".freeze
    SYSTEM = "MOTOR".freeze
    HEADERS = {
      "Origen" => [ "Cod interno", "Número de parte", "Descripción del artículo", "Descripcion", "Grupo de articulos", "Fabricante", "Unidad" ],
      "Aplicaciones" => %w[Referencia Marca Producto Posición Fabricante Modelo Submodelo Año Litros CC CID Cilindros Bloque Combustible Mercado],
      "Intercambios" => [ "Referencia", "Marca", "Producto", "Intercambio", "Marca intercambio", "Origen" ],
      "Atributos" => %w[Referencia Marca Producto Clase Atributo Unidad Valor],
      "Catálogo" => %w[Referencia Marca Categoría Sistema Subsistema Producto Descripción],
      "Fuentes" => [ "Referencia", "Tipo de dato", "Origen", "URL", "Valor original" ],
      "Validación" => [ "Referencia", "Campo", "Valor ERP", "Valor fuente", "URL", "Estado" ]
    }.freeze
    METRIC_BLOCKS = { "Aplicaciones" => 4, "Intercambios" => 8, "Atributos" => 12 }.freeze
    SOURCE_TYPES = %w[aplicación intercambio atributo].freeze

    def self.call(run, path) = new(run).write(path)

    def initialize(run)
      @run = run
      @items = run.source_items.to_a
      @results = @items.to_h { [ _1, Records::ItemResult.from_h(_1.result.presence || empty_result(_1)) ] }
    end

    def write(path)
      package = Axlsx::Package.new
      book = package.workbook
      tables = {
        "Aplicaciones" => application_rows, "Intercambios" => interchange_rows, "Atributos" => attribute_rows
      }
      add_sheet(book, "Origen", origin_rows)
      add_metrics(book, tables)
      tables.each { |name, rows| add_sheet(book, name, rows) }
      add_sheet(book, "Catálogo", catalog_rows)
      add_sheet(book, "Fuentes", source_rows)
      add_sheet(book, "Validación", validation_rows)
      package.serialize(path.to_s)
      path
    end

    private

    def empty_result(item)
      { product: item.product, applications: [], interchanges: [], attributes: [], validations: [] }
    end

    def add_sheet(book, name, rows)
      book.add_worksheet(name: name) do |sheet|
        sheet.add_row HEADERS.fetch(name), types: :string
        rows.each { sheet.add_row _1, types: _1.map { |value| cell_type(value) } }
      end
    end

    # Text stays text even when it looks numeric ("6536" codes are converted
    # before) or starts with "=": data from sources is never a formula.
    def cell_type(value)
      case value
      when Integer then :integer
      when Float then :float
      else :string
      end
    end

    def add_metrics(book, tables)
      input_counts = input_row_counts
      book.add_worksheet(name: "Métricas") do |sheet|
        sheet.add_row [ TITLE ], types: :string
        sheet.add_row [ "Referencias:", @items.size ], types: [ :string, :integer ]
        METRIC_BLOCKS.each do |name, row|
          sheet.add_row []
          generated, origin = tables.fetch(name).size, input_counts.fetch(name, 0)
          sheet.add_row [ name, generated ], types: [ :string, :integer ]
          sheet.add_row [ "Origen", origin ], types: [ :string, :integer ]
          # caxlsx escapes "=..." as text by default (formula injection guard);
          # only this row, whose formula we write ourselves, opts out. The
          # cached result is for readers that do not recalculate.
          sheet.add_row [ "Incrementos", "=B#{row}-B#{row + 1}" ], types: [ :string, nil ],
            escape_formulas: [ true, false ], formula_values: [ nil, generated - origin ]
        end
      end
    end

    # "Origen" in Métricas: rows the input workbook already had in that sheet.
    def input_row_counts
      return {} unless @run.input.attached?

      @run.input.open do |file|
        book = Roo::Excelx.new(file.path, extension: :xlsx)
        METRIC_BLOCKS.keys.to_h do |name|
          next [ name, 0 ] unless book.sheets.include?(name)

          sheet = book.sheet(name)
          count = (2..sheet.last_row.to_i).count { |r| sheet.row(r).compact.any? }
          [ name, count ]
        end
      end
    end

    def origin_rows
      @items.map do |item|
        [ number_or_text(item.internal_code), item.part_number, item.item_description, item.description, item.item_group, item.manufacturer, item.unit ]
      end
    end

    def number_or_text(value) = value.to_s.match?(/\A\d+\z/) ? value.to_i : value

    def application_rows
      each_item do |item, result|
        rows = result.applications.map do |app|
          [ item.part_number, brand(item), result.product, nil, app.manufacturer, app.model, app.submodel, app.year,
            app.liters, app.cc, app.cid, app.cylinders, app.block, app.fuel, app.market ]
        end
        rows.uniq.sort_by { |r| [ r[4].to_s, r[5].to_s, r[6].to_s, r[7].to_i, r[8].to_f, r[13].to_s, r[14].to_s ] }
      end
    end

    def interchange_rows
      each_item do |item, result|
        rows = result.interchanges.map { [ item.part_number, brand(item), result.product, _1.number, _1.brand, _1.kind ] }
        rows.uniq.sort_by { [ _1[4].to_s, _1[3].to_s ] }
      end
    end

    def attribute_rows
      each_item do |item, result|
        CatalogDescription.ordered(result.attributes, attribute_order(result.product)).map do |attr|
          [ item.part_number, brand(item), result.product, attr.klass, attr.name, attr.unit, attr.value ]
        end.uniq
      end
    end

    # A part without source data gets only reference, brand and product.
    def catalog_rows
      @items.map do |item|
        result = @results.fetch(item)
        next [ item.part_number, brand(item), nil, nil, nil, result.product, nil ] unless item.status == "done"

        [ item.part_number, brand(item), CATEGORY, SYSTEM, Normalizer::PRODUCTS.dig(result.product, "subsystem"), result.product,
          CatalogDescription.call(product: result.product, attributes: result.attributes) ]
      end
    end

    def source_rows
      each_item do |item, result|
        rows = result.applications.flat_map do |app|
          [ [ "aplicación", app.origin, app.url, app.original ], *app.evidence_urls.to_a.map { |origin, url| [ "aplicación", origin, url, app.original ] } ]
        end
        rows += result.interchanges.map { [ "intercambio", _1.origin, _1.url, _1.number ] }
        rows += result.attributes.map { [ "atributo", _1.origin, _1.url, _1.original ] }
        rows.uniq.sort_by { |type, origin, url, original| [ SOURCE_TYPES.index(type), origin.to_s, url.to_s, original.to_s ] }
            .map { [ item.part_number, *_1 ] }
      end
    end

    # Stable: within a part, by field, then URL, keeping generation order on ties.
    def validation_rows
      each_item do |item, result|
        result.validations.each_with_index
          .sort_by { |v, index| [ v.field.to_s, v.url.to_s, index ] }
          .map { |v, _| [ item.part_number, v.field, v.erp_value, v.source_value, v.url, v.status ] }
          .uniq
      end
    end

    def each_item(&block) = @items.flat_map { block.call(_1, @results.fetch(_1)) }

    def brand(item) = Normalizer.brand_for(item.manufacturer)

    def attribute_order(product) = Normalizer::PRODUCTS.dig(product, "attribute_order").to_a
  end
end
