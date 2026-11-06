module Catalog
  # Reads the "Origen" sheet of the ERP workbook. Columns are found by their
  # exact header text, not by position.
  class SourceWorkbook
    class InvalidFile < StandardError; end

    SHEET = "Origen".freeze
    COLUMNS = {
      "Cod interno" => :internal_code,
      "Número de parte" => :part_number,
      "Descripción del artículo" => :item_description,
      "Descripcion" => :description,
      "Grupo de articulos" => :item_group,
      "Fabricante" => :manufacturer,
      "Unidad" => :unit
    }.freeze

    def self.read(path) = new(path).rows

    def initialize(path)
      @path = path.to_s
    end

    def rows
      sheet = open_sheet
      index = header_index(sheet.row(1))

      rows = (2..sheet.last_row.to_i).filter_map do |number|
        values = sheet.row(number)
        row = COLUMNS.values.to_h { |key| [ key, cell_text(values[index[key]]) ] }
        row.merge(origin_values: COLUMNS.values.map { origin_value(values[index[_1]]) }) if row[:part_number].present?
      end
      # With no parts no job would run and the run page would wait forever.
      raise InvalidFile, "La hoja Origen no tiene piezas." if rows.empty?

      rows.each_with_index.map { |row, position| row.merge(position: position) }
    end

    private

    def open_sheet
      # Uploaded temp files have arbitrary extensions, so the format is forced.
      book = Roo::Excelx.new(@path, extension: :xlsx)
      raise InvalidFile, "El archivo no tiene la hoja Origen." unless book.sheets.include?(SHEET)

      book.sheet(SHEET)
    rescue Zip::Error, ArgumentError, IOError, TypeError
      raise InvalidFile, "El archivo no es un Excel (.xlsx) válido con la hoja Origen."
    end

    def header_index(headers)
      headers = headers.map { cell_text(_1) }
      missing = COLUMNS.keys - headers
      if missing.any?
        raise InvalidFile, "A la hoja Origen le faltan columnas: #{missing.join(', ')}."
      end

      COLUMNS.to_h { |title, key| [ key, headers.index(title) ] }
    end

    # The cell as it is in the input, for the Origen sheet: a number stays a
    # number (6536.0 → 6536) and text stays text, leading zeros included.
    def origin_value(value)
      case value
      when nil, String then value
      when Float then value == value.floor ? value.to_i : value
      when Numeric then value
      else value.to_s
      end
    end

    # Excel stores codes like 6536 as 6536.0; keep whole numbers without ".0".
    def cell_text(value)
      case value
      when nil then nil
      when Float then value == value.floor ? value.to_i.to_s : value.to_s
      else value.to_s.strip.presence
      end
    end
  end
end
