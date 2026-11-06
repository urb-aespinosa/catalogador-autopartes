require "test_helper"

class Catalog::InegiSalesFilterTest < ActiveSupport::TestCase
  HEADER = %w[PROD_EST COBERTURA ANIO ID_MES MARCA MODELO TIPO SEGMENTO ORIGEN ID_PAIS_ORIGEN UNI_VEH ESTATUS].freeze
  PROJECT = "Registro Administrativo de la Industria Automotriz de Vehículos Ligeros. Venta de vehículos ".freeze

  setup do
    @dir = Rails.root.join("tmp/inegi_filter_test_#{Process.pid}")
    FileUtils.mkdir_p(@dir)
    @output = @dir.join("filtered.csv")
  end

  teardown { FileUtils.rm_rf(@dir) }

  def row(year, month, make, model, units, segment: "Pick Ups")
    [ PROJECT, "Nacional", year, month, make, model, "Camiones ligeros", segment, "NACIONAL", 1, units, "Cifras Definitivas" ]
  end

  # A small zip shaped like INEGI's: one CSV per year plus other files.
  def build_zip(files, header: HEADER)
    path = @dir.join("raiavl.zip")
    Zip::OutputStream.open(path.to_s) do |zip|
      files.each do |year, rows|
        zip.put_next_entry("conjunto_de_datos/raiavl_venta_mensual_tr_cifra_#{year}.csv")
        zip.write(CSV.generate(force_quotes: true) { |csv| ([ header ] + rows).each { csv << _1 } })
      end
      zip.put_next_entry("catalogos/tc_mes.csv")
      zip.write("\"ID_MES\",\"NOMBRE\"\n")
    end
    path
  end

  def filter(zip) = Catalog::InegiSalesFilter.call(zip, @output)

  test "keeps Nissan and General Motors, drops constant columns and sorts totally" do
    zip = build_zip({
      2006 => [ row(2006, "01", "Toyota", "Hilux", 5), row(2006, "01", "Nissan", "Tsuru 4 PTS", 900) ],
      2005 => [
        row(2005, "02", "General Motors", "Silverado 1500 Cabina Regular", 40),
        row(2005, "01", "Nissan", "Pickup Largo", 0),
        row(2005, "01", "General Motors", "Cavalier 4 Ptas", 12, segment: "Compactos")
      ]
    })

    filter(zip)

    assert_equal <<~CSV, File.read(@output)
      ANIO,ID_MES,MARCA,MODELO,TIPO,SEGMENTO,ORIGEN,ID_PAIS_ORIGEN,UNI_VEH,ESTATUS
      2005,01,General Motors,Cavalier 4 Ptas,Camiones ligeros,Compactos,NACIONAL,1,12,Cifras Definitivas
      2005,01,Nissan,Pickup Largo,Camiones ligeros,Pick Ups,NACIONAL,1,0,Cifras Definitivas
      2005,02,General Motors,Silverado 1500 Cabina Regular,Camiones ligeros,Pick Ups,NACIONAL,1,40,Cifras Definitivas
      2006,01,Nissan,Tsuru 4 PTS,Camiones ligeros,Pick Ups,NACIONAL,1,900,Cifras Definitivas
    CSV
  end

  test "values are copied verbatim (names are normalized later, not here)" do
    zip = build_zip({ 2019 => [ row(2019, "03", "General Motors", "Cheyenne  Doble Cabina", 7) ] })

    filter(zip)

    assert_includes File.read(@output), ",Cheyenne  Doble Cabina,"
  end

  test "two runs over the same zip produce identical bytes" do
    zip = build_zip({ 2005 => [ row(2005, "01", "Nissan", "Pickup Largo", 3), row(2005, "01", "Nissan", "Estacas Largo", 3) ] })

    filter(zip)
    first = File.binread(@output)
    filter(zip)

    assert_equal first, File.binread(@output)
  end

  test "an unexpected header fails loudly instead of writing a wrong file" do
    zip = build_zip({ 2005 => [] }, header: HEADER.reverse)

    error = assert_raises(Catalog::InegiSalesFilter::FormatError) { filter(zip) }
    assert_match "raiavl_venta_mensual_tr_cifra_2005.csv", error.message
    assert_not File.exist?(@output)
  end

  test "the committed filtered CSV is exactly what the committed zip produces" do
    Catalog::InegiSalesFilter.call(Catalog::InegiSalesFilter::SOURCE, @output)

    assert_equal Digest::SHA256.file(Catalog::InegiSalesFilter::OUTPUT).hexdigest, Digest::SHA256.file(@output).hexdigest
  end
end
