require "test_helper"

class Catalog::WorkbookExporterTest < ActiveSupport::TestCase
  setup do
    stub_all_sources_from_fixtures
    @path = Rails.root.join("tmp/export_test_#{Process.pid}.xlsx")
  end

  teardown { FileUtils.rm_f(@path) }

  def export
    @export ||= begin
      run = Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx"))
      Catalog::WorkbookExporter.call(run, @path)
      workbook_rows(@path)
    end
  end

  def header(sheet) = export[sheet].first
  def rows(sheet) = export[sheet].drop(1)

  test "sheet names in order" do
    export
    assert_equal %w[Origen Métricas Aplicaciones Intercambios Atributos Catálogo Fuentes Validación], sheet_names(@path)
  end

  test "headers match the evaluator example exactly" do
    example = workbook_rows(file_fixture("ejemplo_prueba_tecnica.xlsx"))

    %w[Origen Aplicaciones Intercambios Atributos Catálogo].each do |sheet|
      assert_equal example[sheet].first.compact, header(sheet), sheet
    end
  end

  test "headers of the extra sheets" do
    assert_equal [ "Referencia", "Tipo de dato", "Origen", "URL", "Valor original" ], header("Fuentes")
    assert_equal [ "Referencia", "Campo", "Valor ERP", "Valor fuente", "URL", "Estado" ], header("Validación")
  end

  test "Origen copies the input rows" do
    assert_equal [ 6536, "FSX-5840301", "JUEGO DE EMPAQUES" ], rows("Origen").first.values_at(0, 1, 2)
    assert_equal 5, rows("Origen").size
  end

  test "metrics block with formulas" do
    m = export["Métricas"]

    assert_equal "Catálogo Bonaparte - Refaccionaria Trópico de Cáncer", m[0][0]
    assert_equal [ "Referencias:", 5 ], m[1].first(2)
    assert_equal [ "Aplicaciones", rows("Aplicaciones").size ], m[3].first(2)
    assert_equal [ "Origen", 0 ], m[4].first(2)
    assert_equal [ "Incrementos", "=B4-B5" ], m[5].first(2)
    assert_equal [ "Intercambios", rows("Intercambios").size ], m[7].first(2)
    assert_equal [ "Incrementos", "=B8-B9" ], m[9].first(2)
    assert_equal [ "Atributos", rows("Atributos").size ], m[11].first(2)
    assert_equal [ "Incrementos", "=B12-B13" ], m[13].first(2)
  end

  test "numeric cells are numbers and text stays text" do
    row = rows("Aplicaciones").find { _1[0] == "FSX-5840301" }

    assert_kind_of Integer, row[7]   # Año
    assert_kind_of Float, row[8]     # Litros
    assert_equal [ "FRACO", "JUEGO DE EMPAQUES DE MOTOR", nil, "Nissan" ], row.values_at(1, 2, 3, 4)
    assert_equal "MEX", row[14]
  end

  test "rows follow the source order, then a total order inside each part" do
    references = rows("Aplicaciones").map(&:first).uniq
    assert_equal references, %w[FSX-5840301 HL-7025S RM-152 SP26-329R/L+20] & references

    fraco = rows("Aplicaciones").select { _1[0] == "FSX-5840301" }
    assert_equal fraco.sort_by { [ _1[4].to_s, _1[5].to_s, _1[6].to_s, _1[7].to_i ] }, fraco
  end

  test "an item without source still appears in Catálogo with the minimum" do
    revo = rows("Catálogo").find { _1[0] == "TK1283-1" }

    assert_equal [ "TK1283-1", "REVO", nil, nil, nil, "KIT DE DISTRIBUCIÓN", nil ], revo
  end

  test "Catálogo has taxonomy and the template description" do
    fraco = rows("Catálogo").find { _1[0] == "FSX-5840301" }

    assert_equal [ "Vehículo ligero", "MOTOR", "JUNTAS Y SISTEMAS DE SELLADO", "JUEGO DE EMPAQUES DE MOTOR" ], fraco.values_at(2, 3, 4, 5)
    assert fraco[6].start_with?("Juego de empaques de motor para sellar las uniones del motor. Número de válvulas: 12.")
  end

  test "Atributos follow the product order with translated values" do
    lifters = rows("Atributos").select { _1[0] == "HL-7025S" }

    assert_equal [ "Tipo de puntería", "Rodillo", "Material", "Longitud", "Diámetro exterior máximo" ], lifters.map { _1[4] }
    assert_equal [ "Longitud", "Longitud", "mm", 98.55 ], lifters.find { _1[4] == "Longitud" }.values_at(3, 4, 5, 6)
  end

  test "Fuentes traces every row to its URL, with evidence and original values" do
    fuentes = rows("Fuentes")

    assert_includes fuentes.map { _1.values_at(0, 1, 2) }, [ "HL-7025S", "atributo", "oficial" ]
    assert_includes fuentes.map { _1.values_at(0, 1, 4) }, [ "HL-7025S", "atributo", "3.880 IN" ]
    assert fuentes.any? { _1[0] == "HL-7025S" && _1[2] == "verificación NHTSA vPIC" && _1[3].start_with?("https://vpic.nhtsa.dot.gov") }
    assert_includes fuentes.map { _1.values_at(0, 2) }, [ "SP26-329R/L+20", "número de parte" ]
    assert_equal fuentes.uniq, fuentes
  end

  test "Validación reports source status per part" do
    validacion = rows("Validación")

    assert_includes validacion.map { _1.values_at(0, 1, 5) }, [ "TK1283-1", "Fuente", "no encontrado" ]
    assert_includes validacion.map { _1.values_at(0, 1, 2, 5) }, [ "HL-7025S", "Unidad", "PZA", "difiere" ]
  end

  test "interchange kind is OEM for vehicle makers" do
    run = Run.create!
    item = run.source_items.create!(position: 0, part_number: "DM-152", manufacturer: "TECH OIL PUMPS", item_group: "BOMBA DE ACEITE", status: "done", product: "BOMBA DE ACEITE DEL MOTOR",
                                    result: Catalog::Records::ItemResult.new(product: "BOMBA DE ACEITE DEL MOTOR", applications: [], attributes: [], validations: [],
                                      interchanges: [ Catalog::Records::Interchange.new(number: "15010-F450A", brand: "Nissan", kind: "OEM", url: "u", origin: "oficial") ]).to_h)
    Catalog::WorkbookExporter.call(run, @path)

    assert_equal [ "DM-152", "TECH OIL PUMPS", "BOMBA DE ACEITE DEL MOTOR", "15010-F450A", "Nissan", "OEM" ], workbook_rows(@path)["Intercambios"][1]
    assert item.persisted?
  end
end
