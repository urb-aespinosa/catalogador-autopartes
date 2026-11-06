require "test_helper"

class Catalog::NormalizerTest < ActiveSupport::TestCase
  def item(group: "PUNTERIAS", manufacturer: "ELGIN")
    SourceItem.new(part_number: "X-1", item_group: group, manufacturer: manufacturer)
  end

  def attr(name, value, unit = nil, origin: "oficial")
    Catalog::Records::Attribute.new(klass: nil, name: name, unit: unit, value: value, url: "https://src", origin: origin, original: [ value, unit ].compact.join(" "))
  end

  def app(**values)
    Catalog::Records::Application.new(**Catalog::Records::Application.members.index_with(nil), origin: "oficial", url: "https://src", evidence_urls: [], **values)
  end

  def result(attributes: [], applications: [], product_kind: :set, interchanges: [], validations: [])
    Sources::Result.found(market: "USA", product_kind: product_kind, attributes: attributes, applications: applications, interchanges: interchanges, validations: validations)
  end

  def normalize(source_result, **item_values) = Catalog::Normalizer.call(item: item(**item_values), result: source_result)

  test "inches to mm, always 2 decimals" do
    assert_equal 98.55, Catalog::Normalizer.inches_to_mm(3.880)
    assert_equal 21.39, Catalog::Normalizer.inches_to_mm(0.842)
    assert_equal 25.4, Catalog::Normalizer.inches_to_mm(1)
  end

  test "translates Elgin attributes, converts inches and keeps the original" do
    out = normalize(result(attributes: [ attr("Length", "3.880", "IN"), attr("Lifter Type", "Hydraulic"), attr("Roller", "Yes") ]))

    length = out.attributes.find { _1.name == "Longitud" }
    assert_equal [ "Longitud", "mm", 98.55, "3.880 IN" ], [ length.klass, length.unit, length.value, length.original ]
    assert_equal "Hidráulica", out.attributes.find { _1.name == "Tipo de puntería" }.value
    assert_equal "Sí", out.attributes.find { _1.name == "Rodillo" }.value
    assert_empty out.validations
  end

  test "numeric strings become numbers" do
    out = normalize(result(attributes: [ attr("Número de válvulas", "12"), attr("Diámetro", "89", "mm") ]), group: "JUEGO DE EMPAQUES", manufacturer: "FRACO")

    assert_equal [ 12, 89 ], out.attributes.map(&:value)
    assert_equal [ nil, "mm" ], out.attributes.map(&:unit)
  end

  test "an unknown attribute name stays original and is reported" do
    out = normalize(result(attributes: [ attr("Plating", "Zinc") ]))

    assert_equal [ "Plating", "Zinc" ], [ out.attributes.first.name, out.attributes.first.value ]
    assert_equal [ [ "Traducción", "Plating", "sin traducción" ], [ "Traducción", "Zinc", "sin traducción" ] ],
                 out.validations.map { [ _1.field, _1.source_value, _1.status ] }
  end

  test "an unknown categorical value stays original and is reported" do
    out = normalize(result(attributes: [ attr("Material", "Unobtainium") ]))

    assert_equal "Unobtainium", out.attributes.first.value
    assert_equal [ "Traducción", "Unobtainium", "sin traducción" ], out.validations.first.then { [ _1.field, _1.source_value, _1.status ] }
  end

  test "fuels and makes" do
    out = normalize(result(applications: [ app(manufacturer: "CHEVROLET", fuel: "MILD HYBRID EV-GAS (MHEV)"), app(manufacturer: "BUICK", fuel: "GAS") ]))

    assert_equal [ [ "Chevrolet", "Híbrido MHEV" ], [ "Buick", "Gasolina" ] ], out.applications.map { [ _1.manufacturer, _1.fuel ] }
  end

  test "an unknown fuel stays original and is reported" do
    out = normalize(result(applications: [ app(manufacturer: "CHEVROLET", fuel: "HYDROGEN") ]))

    assert_equal "HYDROGEN", out.applications.first.fuel
    assert_equal "sin traducción", out.validations.first.status
  end

  test "oversize is a designation from the fixed table, not a conversion" do
    out = normalize(result(attributes: [ attr("Sobremedida", "+20", origin: "número de parte") ], product_kind: nil), group: "PISTONES", manufacturer: "SAFETY")

    oversize = out.attributes.first
    assert_equal [ "Sobremedida", "Sobremedida", nil, "0.50 mm (+0.020\")", "número de parte" ], [ oversize.klass, oversize.name, oversize.unit, oversize.value, oversize.origin ]
  end

  test "an unknown oversize designation is reported" do
    out = normalize(result(attributes: [ attr("Sobremedida", "+25", origin: "número de parte") ], product_kind: nil), group: "PISTONES")

    assert_equal "sin traducción", out.validations.first.status
  end

  test "Fraco head gasket codes follow the sheet legend" do
    out = normalize(result(attributes: [ attr("Junta Cabeza", "MLO"), attr("Junta Cabeza", "SB") ], product_kind: nil), group: "JUEGO DE EMPAQUES")

    assert_equal [ "MLS", "No asbesto" ], out.attributes.map(&:value)
    assert_equal [ "Material", "Material" ], out.attributes.map(&:klass)
  end

  test "product from the source kind, fallback to the ERP group" do
    assert_equal "JUEGO DE PUNTERÍAS DE MOTOR", Catalog::Normalizer.product_for(item_group: "PUNTERIAS", product_kind: :set)
    assert_equal "KIT DE CADENA DE TIEMPO", Catalog::Normalizer.product_for(item_group: "KIT DE DISTRIBUCION", product_kind: :chain)
    assert_equal "KIT DE DISTRIBUCIÓN", Catalog::Normalizer.product_for(item_group: "KIT DE DISTRIBUCION", product_kind: nil)
    assert_equal "PISTÓN DE MOTOR", Catalog::Normalizer.product_for(item_group: "PISTONES", product_kind: nil)
    assert_equal "BOMBA DE ACEITE DEL MOTOR", Catalog::Normalizer.product_for(item_group: "BOMBA DE ACEITE", product_kind: nil)
    assert_equal "JUEGO DE EMPAQUES DE MOTOR", Catalog::Normalizer.product_for(item_group: "JUEGO DE EMPAQUES", product_kind: nil)
  end

  test "an item without source gets its product from the ERP group and no rows" do
    out = Catalog::Normalizer.call(item: item(group: "KIT DE DISTRIBUCION", manufacturer: "REVO"), result: nil)

    assert_equal "KIT DE DISTRIBUCIÓN", out.product
    assert_empty out.applications
    assert_empty out.attributes
  end

  test "an ERP group without a rule keeps its text and is reported" do
    out = Catalog::Normalizer.call(item: item(group: "PUNTERIAS", manufacturer: "ELGIN"), result: nil)

    assert_equal "PUNTERIAS", out.product
    assert_equal [ "Producto", "PUNTERIAS", "sin traducción" ], out.validations.first.then { [ _1.field, _1.erp_value, _1.status ] }
  end

  test "brands follow the dictionary" do
    assert_equal "HASTINGS PISTON RINGS", Catalog::Normalizer.brand_for("HASTING")
    assert_equal "TECH TIMING", Catalog::Normalizer.brand_for("TECH TIMMING")
    assert_equal "FRACO", Catalog::Normalizer.brand_for("FRACO")
  end

  test "interchanges get their kind from the OEM list" do
    out = normalize(result(interchanges: [ Catalog::Records::Interchange.new(number: "15010-F450A", brand: "Nissan", kind: nil, url: "u", origin: "oficial"),
                                           Catalog::Records::Interchange.new(number: "M152", brand: "Melling", kind: nil, url: "u", origin: "oficial") ]))

    assert_equal %w[OEM Aftermarket], out.interchanges.map(&:kind)
  end

  test "source validations are kept" do
    validation = Catalog::Records::Validation.new(field: "Fabricante", erp_value: nil, source_value: "Savana", url: "u", status: "no encontrado")

    assert_includes normalize(result(validations: [ validation ])).validations, validation
  end

  test "every product has subsystem, opening and attribute order" do
    Catalog::Normalizer::PRODUCTS.each do |name, product|
      assert product["subsystem"].present?, name
      assert product["opening"].end_with?("."), name
      assert_kind_of Array, product["attribute_order"], name
    end
  end
end
