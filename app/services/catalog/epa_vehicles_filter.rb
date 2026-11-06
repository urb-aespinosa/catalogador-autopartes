module Catalog
  # Builds the readable, versioned extract of EPA's bulk vehicles.csv (D19)
  # from the original zip: only the makes our parts apply to and only the
  # columns the market resolver uses, in a total and stable order. Columns are
  # picked by name because EPA's file has ~84 of them and their order is not
  # a contract. Values are copied verbatim.
  class EpaVehiclesFilter
    class FormatError < StandardError; end

    DIR = Rails.root.join("db/reference/epa")
    SOURCE = DIR.join("vehicles.csv.zip")
    OUTPUT = DIR.join("vehicles_scope.csv")
    MAKES = %w[Buick Cadillac Chevrolet GMC Hummer Isuzu Nissan Pontiac Saab].freeze
    COLUMNS = %w[year make model id displ cylinders fuelType atvType].freeze

    def self.call(source = SOURCE, output = OUTPUT, makes: MAKES) = new(source, output, makes).call

    def initialize(source, output, makes)
      @source = source.to_s
      @output = output.to_s
      @makes = makes
    end

    # Everything is read and checked before writing, so a format change never
    # leaves a half-written file behind.
    def call
      rows = read_rows.sort_by { sort_key(_1) }
      File.write(@output, CSV.generate(row_sep: "\n") { |csv| ([ COLUMNS ] + rows).each { csv << _1 } })
      rows.size
    end

    private

    def read_rows
      text = Zip::File.open(@source) do |zip|
        entries = zip.entries.select { _1.name.end_with?(".csv") }
        raise FormatError, "se esperaba un solo .csv en #{File.basename(@source)}" unless entries.size == 1

        entries.first.get_input_stream.read.force_encoding("UTF-8")
      end
      table = CSV.parse(text, headers: true)
      missing = COLUMNS - table.headers
      raise FormatError, "#{File.basename(@source)}: faltan columnas #{missing.join(', ')}" if missing.any?

      # A quoted empty cell ("") and a bare one mean the same: no value.
      table.select { @makes.include?(_1["make"]) }.map { |row| COLUMNS.map { row[_1].presence } }
    end

    # year, make, model, id, displ, cylinders, fuelType, atvType
    def sort_key(row)
      [ row[0].to_i, row[1], row[2], row[3].to_i, row[4].to_f, row[5].to_i, row[6].to_s, row[7].to_s ]
    end
  end
end
