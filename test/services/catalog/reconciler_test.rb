require "test_helper"

class Catalog::ReconcilerTest < ActiveSupport::TestCase
  RM152 = "DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14".freeze

  def app(**values)
    Catalog::Records::Application.new(**Catalog::Records::Application.members.index_with(nil), origin: "oficial", url: "https://src", evidence_urls: [], **values)
  end

  def item_result(product: "BOMBA DE ACEITE DEL MOTOR", applications: [], interchanges: [], attributes: [])
    Catalog::Records::ItemResult.new(product: product, applications: applications, interchanges: interchanges, attributes: attributes, validations: [])
  end

  def rexite_280zx
    item_result(applications: [ 1981, 1982 ].map { app(manufacturer: "Nissan", model: "280ZX", year: _1, liters: 2.8, cylinders: 6, block: "L") })
  end

  def reconcile(description, result, unit: "PZA")
    item = SourceItem.new(part_number: "X", description: description, unit: unit)
    Catalog::Reconciler.call(item: item, hints: Catalog::DescriptionParser.call(description), result: result)
  end

  def status(validations, field, erp_value = nil)
    rows = validations.select { _1.field == field && (erp_value.nil? || _1.erp_value == erp_value) }
    assert_equal 1, rows.size, "expected one #{field} #{erp_value} row, got #{rows.map(&:to_h)}"
    rows.first.status
  end

  test "RM-152 hints against the Rexite 280ZX" do
    v = reconcile(RM152, rexite_280zx)

    assert_equal "coincide", status(v, "Armadora")
    assert_equal "coincide", status(v, "Años")
    assert_equal "difiere", status(v, "Modelo")
    assert_equal "coincide", status(v, "Cilindros", "6")
    assert_equal "difiere", status(v, "Cilindros", "4")
    assert_equal "difiere", status(v, "Litros", "2.4")
    assert_equal "no encontrado", status(v, "Intercambio", "DM-152")
    assert_equal "no encontrado", status(v, "Código de motor", "KA24DE")
    assert_equal "no encontrado", status(v, "Válvulas", "12")
  end

  test "values carry what each side says" do
    years = reconcile(RM152, rexite_280zx).find { _1.field == "Años" }

    assert_equal [ "1976-2014", "1981-1982", "https://src" ], [ years.erp_value, years.source_value, years.url ]
  end

  test "model names compare without spaces or case" do
    result = item_result(applications: [ app(manufacturer: "Nissan", model: "Pickup", year: 1991) ])

    assert_equal "coincide", status(reconcile("QJC20G NISSAN PICK UP 4 CIL 2.4 KA24E 89/03", result), "Modelo")
  end

  test "valves compare against the source attribute" do
    attrs = [ Catalog::Records::Attribute.new(klass: "Número", name: "Número de válvulas", unit: nil, value: 12, url: "u", origin: "oficial", original: "12") ]
    result = item_result(applications: [ app(manufacturer: "Nissan", model: "D21", year: 1991) ], attributes: attrs)

    assert_equal "coincide", status(reconcile("NISSAN PICK UP 4 CIL 2.4 12 VAL 89/03", result), "Válvulas")
  end

  test "interchange numbers compare without hyphens" do
    result = item_result(interchanges: [ Catalog::Records::Interchange.new(number: "DM152", brand: "Tech", kind: "Aftermarket", url: "u", origin: "oficial") ])

    assert_equal "coincide", status(reconcile(RM152, result), "Intercambio", "DM-152")
  end

  test "years without overlap differ" do
    result = item_result(applications: [ app(manufacturer: "Chevrolet", model: "Silverado", year: 2014) ])

    assert_equal "difiere", status(reconcile("CHEVROLET SILVERADO V6 4.3 89/90", result), "Años")
  end

  test "unit PZA against a set differs" do
    result = item_result(product: "JUEGO DE PUNTERÍAS DE MOTOR", applications: [ app(manufacturer: "Chevrolet", model: "Silverado", year: 2014) ])

    unit = reconcile("CHEVROLET SILVERADO 99/23", result).find { _1.field == "Unidad" }
    assert_equal [ "PZA", "JUEGO DE PUNTERÍAS DE MOTOR", "difiere" ], [ unit.erp_value, unit.source_value, unit.status ]
  end

  test "unit JUEGO against a set matches" do
    result = item_result(product: "JUEGO DE EMPAQUES DE MOTOR", applications: [ app(manufacturer: "Nissan", model: "D21", year: 1991) ])

    assert_equal "coincide", status(reconcile("NISSAN D21 89/03", result, unit: "JUEGO"), "Unidad")
  end

  test "without source data every hint is not found" do
    v = reconcile("9-0511S CHRYSLER DURANGO V6 3.6 11/13", item_result(product: "KIT DE DISTRIBUCIÓN"), unit: "JUEGO")

    assert v.any?
    assert v.all? { _1.status == "no encontrado" }, v.map(&:to_h).inspect
  end
end
