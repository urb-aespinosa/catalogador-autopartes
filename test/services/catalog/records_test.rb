require "test_helper"

class Catalog::RecordsTest < ActiveSupport::TestCase
  test "ItemResult round-trips through JSON" do
    app = Catalog::Records::Application.new(
      manufacturer: "Nissan", model: "280ZX", submodel: nil, year: 1981, years: nil,
      liters: 2.8, cc: nil, cid: nil, cylinders: 6, block: "L", fuel: nil, market: "MEX",
      url: "https://rexite.net/x", origin: "oficial", original: "Nissan 280Zx 1981",
      evidence_urls: [ [ "verificación NHTSA vPIC", "https://vpic/x" ] ]
    )
    result = Catalog::Records::ItemResult.new(
      product: "BOMBA DE ACEITE DEL MOTOR",
      applications: [ app ],
      interchanges: [ Catalog::Records::Interchange.new(number: "M152", brand: "Melling", kind: "Aftermarket", url: "u", origin: "oficial") ],
      attributes: [ Catalog::Records::Attribute.new(klass: "Longitud", name: "Longitud", unit: "mm", value: 98.55, url: "u", origin: "oficial", original: "3.880 IN") ],
      validations: [ Catalog::Records::Validation.new(field: "Modelo", erp_value: "PICKUP", source_value: "280ZX", url: "u", status: "difiere") ]
    )

    assert_equal result, Catalog::Records::ItemResult.from_h(JSON.parse(result.to_h.to_json))
  end

  test "Application years range survives JSON" do
    app = Catalog::Records::Application.new(**Catalog::Records::Application.members.index_with(nil), years: 2007..2020)
    restored = Catalog::Records::Application.from_h(JSON.parse(app.to_h.to_json))

    assert_equal 2007..2020, restored.years
  end
end
