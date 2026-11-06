require "test_helper"

class Catalog::MarketResolverTest < ActiveSupport::TestCase
  INEGI_URL = Catalog::InegiSales::SOURCE_URL
  GM = "General Motors".freeze

  def application(**values)
    Catalog::Records::Application.new(
      **Catalog::Records::Application.members.index_with(nil),
      origin: "oficial", url: "https://src", evidence_urls: [], liters: 5.3, cylinders: 8, **values
    )
  end

  def sale(year, make, model, units)
    { "ANIO" => year.to_s, "ID_MES" => "01", "MARCA" => make, "MODELO" => model, "UNI_VEH" => units.to_s }
  end

  def inegi
    Catalog::InegiSales.new(
      models: {
        "Nissan" => { "Pickup" => [ { "marca" => "Nissan", "modelo" => "Pickup Largo" } ] },
        "Chevrolet" => {
          "Silverado 2500 HD" => [ { "marca" => GM, "modelo" => "Silverado 2500 Doble Cabina-" } ],
          "Silverado 1500" => [ { "marca" => GM, "modelo" => "Silverado 1500 Cabina Regular" } ],
          "Sonora" => [ { "marca" => GM, "modelo" => "Sonora Suv" } ]
        }
      },
      rows: [
        sale(2010, "Nissan", "Pickup Largo", 120),
        sale(2016, GM, "Silverado 2500 Doble Cabina-", 40),
        *(2014..2016).map { sale(_1, GM, "Silverado 1500 Cabina Regular", 10) },
        *(2005..2007).map { sale(_1, GM, "Sonora Suv", 5) }
      ]
    )
  end

  def resolve(*apps) = Catalog::MarketResolver.call(apps, inegi: inegi, epa: nil)

  test "MEX catalog with INEGI sales gives one MEX row at level a" do
    apps, validations = resolve(application(manufacturer: "Nissan", model: "Pickup", year: 2010, market: "MEX"))

    assert_equal [ "MEX" ], apps.map(&:market)
    assert_includes apps.first.evidence_urls, [ "mercado MEX: ventas INEGI RAIAVL", INEGI_URL, "Pickup Largo · 2010 · 120 unidades" ]
    assert_equal [ [ "Mercado", "MEX · Nissan Pickup 2010", "confirmado por ventas" ] ],
                 validations.map { [ _1.field, _1.source_value, _1.status ] }
  end

  test "MEX catalog without INEGI sales keeps MEX at level b" do
    apps, validations = resolve(application(manufacturer: "Nissan", model: "D21", year: 1993, market: "MEX", url: "https://fraco/d21"))

    assert_equal [ "MEX" ], apps.map(&:market)
    assert_includes apps.first.evidence_urls, [ "mercado según catálogo", "https://fraco/d21" ]
    assert_equal [ [ "MEX · Nissan D21 1993", "según catálogo", "https://fraco/d21" ] ],
                 validations.map { [ _1.source_value, _1.status, _1.url ] }
  end

  test "USA catalog with INEGI sales gives MEX (a) and USA (b) rows" do
    apps, validations = resolve(application(manufacturer: "Chevrolet", model: "Silverado 2500 HD", year: 2016, market: "USA"))

    assert_equal [ "MEX", "USA" ], apps.map(&:market)
    assert apps.first.evidence_urls.any? { _1.first == "mercado MEX: ventas INEGI RAIAVL" }
    assert_includes apps.last.evidence_urls, [ "mercado según catálogo", "https://src" ]
    assert_not apps.last.evidence_urls.any? { _1.first == "mercado MEX: ventas INEGI RAIAVL" }
    assert_equal [ "confirmado por ventas", "según catálogo" ], validations.map(&:status)
  end

  test "USA catalog without INEGI sales stays USA only" do
    apps, = resolve(application(manufacturer: "Chevrolet", model: "Express 2500", year: 2016, market: "USA"))

    assert_equal [ "USA" ], apps.map(&:market)
  end

  test "validations are grouped with year ranges" do
    _, validations = resolve(*(2014..2016).map { application(manufacturer: "Chevrolet", model: "Silverado 1500", year: _1, market: "USA") })

    assert_equal [ [ "MEX · Chevrolet Silverado 1500 2014-2016", "confirmado por ventas" ],
                   [ "USA · Chevrolet Silverado 1500 2014-2016", "según catálogo" ] ],
                 validations.map { [ _1.source_value, _1.status ] }
  end

  test "an application without year is returned unchanged" do
    app = application(manufacturer: "Nissan", model: "Pickup", year: nil, market: "MEX")

    assert_equal [ [ app ], [] ], resolve(app)
  end

  test "a repeated application does not duplicate rows or validations" do
    app = application(manufacturer: "Nissan", model: "Pickup", year: 2010, market: "MEX")

    apps, validations = resolve(app, app)

    assert_equal 1, apps.size
    assert_equal 1, validations.size
  end

  test "a name vPIC never lists is kept as MEX level a only in years with INEGI sales (D20)" do
    apps, validations = resolve(*(2005..2008).map { application(manufacturer: "Chevrolet", model: "Sonora", year: _1, market: "USA", vpic_unknown: true) })

    assert_equal [ [ 2005, "MEX" ], [ 2006, "MEX" ], [ 2007, "MEX" ] ], apps.map { [ _1.year, _1.market ] }
    assert apps.all? { _1.vpic_unknown.nil? }
    assert_equal [ [ "Mercado", "MEX · Chevrolet Sonora 2005-2007", "confirmado por ventas" ],
                   [ "Modelo-año", "Chevrolet Sonora 2008", "no encontrado" ] ],
                 validations.map { [ _1.field, _1.source_value, _1.status ] }
  end
end
