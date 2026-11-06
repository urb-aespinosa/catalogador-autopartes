module Catalog
  # Builds the readable, versioned extract of INEGI RAIAVL sales (D19) from
  # the original open-data zip: only the manufacturer groups our parts apply
  # to, without the two constant columns, in a total and stable order.
  # Values are copied verbatim; model names are mapped later through the
  # reviewed YAML equivalences.
  class InegiSalesFilter
    class FormatError < StandardError; end

    DIR = Rails.root.join("db/reference/inegi")
    SOURCE = DIR.join("conjunto_de_datos_raiavl_mensual_venta_csv.zip")
    OUTPUT = DIR.join("raiavl_venta_nissan_gm.csv")
    MAKES = [ "Nissan", "General Motors" ].freeze
    YEAR_FILE = %r{\Aconjunto_de_datos/raiavl_venta_mensual_tr_cifra_\d{4}\.csv\z}
    HEADER = %w[PROD_EST COBERTURA ANIO ID_MES MARCA MODELO TIPO SEGMENTO ORIGEN ID_PAIS_ORIGEN UNI_VEH ESTATUS].freeze
    KEPT = HEADER.drop(2).freeze

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
      File.write(@output, CSV.generate(row_sep: "\n") { |csv| ([ KEPT ] + rows).each { csv << _1 } })
      rows.size
    end

    private

    def read_rows
      Zip::File.open(@source) do |zip|
        zip.entries.select { YEAR_FILE.match?(_1.name) }.sort_by(&:name).flat_map { year_rows(_1) }
      end
    end

    def year_rows(entry)
      table = CSV.parse(entry.get_input_stream.read.force_encoding("UTF-8"))
      unless table.first == HEADER
        raise FormatError, "#{File.basename(entry.name)}: encabezado inesperado #{table.first.inspect}"
      end

      table.drop(1).select { @makes.include?(_1[4]) }.map { _1.drop(2) }
    end

    # ANIO, ID_MES, MARCA, MODELO, TIPO, SEGMENTO, ORIGEN, ID_PAIS_ORIGEN, UNI_VEH, ESTATUS
    def sort_key(row)
      [ row[0].to_i, *row[1..6], row[7].to_i, row[8].to_i, row[9] ]
    end
  end
end
