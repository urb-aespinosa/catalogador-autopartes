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

  def vehicle(year, make, model, displ, cylinders, fuel = "Regular")
    { "year" => year.to_s, "make" => make, "model" => model, "id" => "#{year}#{displ}".delete(".").to_i.to_s,
      "displ" => displ.to_s, "cylinders" => cylinders.to_s, "fuelType" => fuel, "atvType" => nil }
  end

  def epa
    Catalog::Epa.new(
      models: { "Chevrolet" => { "Silverado 1500" => [ "Silverado C15 2WD" ], "Express 2500" => [ "Express 1500/2500 2WD" ] },
                "Buick" => { "Allure" => [ "Lacrosse/Allure" ] },
                "Cadillac" => { "CTS" => [ "CTS" ] },
                "Nissan" => { "D21" => [ "Truck 2WD" ] } },
      confirm_only: { "Chevrolet" => [ "Express 2500" ] },
      confirm_only_years: [ { "make" => "Cadillac", "model" => "CTS", "year" => 2009, "liters" => 6.2, "cylinders" => 8, "reason" => "gap" } ],
      rows: [
        vehicle(2010, "Chevrolet", "Silverado C15 2WD", 4.3, 6), vehicle(2010, "Chevrolet", "Silverado C15 2WD", 5.3, 8),
        vehicle(2005, "Buick", "Lacrosse/Allure", 3.6, 6), vehicle(2005, "Buick", "Lacrosse/Allure", 3.8, 6),
        vehicle(1993, "Nissan", "Truck 2WD", 3.0, 6),
        vehicle(2007, "Chevrolet", "Express 1500/2500 2WD", 5.3, 8),
        vehicle(2009, "Cadillac", "CTS", 3.6, 6)
      ]
    )
  end

  def resolve_usa(*apps) = Catalog::MarketResolver.call(apps, inegi: inegi, epa: epa)

  def epa_evidence?(app) = app.evidence_urls.any? { _1.first == "mercado USA: EPA fueleconomy.gov" }

  test "EPA engine match gives USA level a" do
    apps, validations = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2010, liters: 4.3, cylinders: 6, market: "USA"))

    usa = apps.find { _1.market == "USA" }
    assert_includes usa.evidence_urls, [ "mercado USA: EPA fueleconomy.gov",
                                         "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2010&make=Chevrolet&model=Silverado%20C15%202WD" ]
    assert_includes validations.map { [ _1.source_value, _1.status ] }, [ "USA · Chevrolet Silverado 1500 2010", "confirmado por EPA" ]
  end

  test "USA catalog engine refuted by EPA removes the application in every market" do
    inegi_with_allure = Catalog::InegiSales.new(models: { "Buick" => { "Allure" => [ { "marca" => GM, "modelo" => "Allure" } ] } },
                                                rows: [ sale(2005, GM, "Allure", 9) ])
    apps, validations = Catalog::MarketResolver.call([ application(manufacturer: "Buick", model: "Allure", year: 2005, market: "USA") ],
                                                     inegi: inegi_with_allure, epa: epa)

    assert_empty apps
    motor = validations.select { _1.field == "Motor" }
    assert_equal [ "difiere" ], motor.map(&:status)
    assert_match "Buick Allure 2005 5.3L 8 cil · EPA: 3.6L 6 cil, 3.8L 6 cil · https://www.fueleconomy.gov/", motor.first.source_value
    assert_empty validations.select { _1.field == "Mercado" }
  end

  test "MEX catalog engine refuted by EPA keeps MEX and denies USA" do
    apps, validations = resolve_usa(application(manufacturer: "Nissan", model: "D21", year: 1993, liters: 2.4, cylinders: 4, market: "MEX"))

    assert_equal [ "MEX" ], apps.map(&:market)
    assert_equal [ "difiere" ], validations.select { _1.field == "Motor" }.map(&:status)
  end

  test "without engine data EPA presence is enough for USA level a" do
    apps, = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2010, liters: nil, cylinders: nil, market: "USA"))

    assert epa_evidence?(apps.find { _1.market == "USA" })
  end

  test "liters are compared rounded to one decimal" do
    apps, validations = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2010, liters: 5.33, cylinders: 8, market: "USA"))

    assert epa_evidence?(apps.find { _1.market == "USA" })
    assert_empty validations.select { _1.field == "Motor" }
  end

  test "EPA without that model-year leaves USA at level b for a USA catalog" do
    apps, validations = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 2500 HD", year: 2016, liters: 6.0, cylinders: 8, market: "USA"))

    assert_equal [ "MEX", "USA" ], apps.map(&:market)
    assert_not epa_evidence?(apps.last)
    assert_includes validations.map { [ _1.source_value, _1.status ] }, [ "USA · Chevrolet Silverado 2500 HD 2016", "según catálogo" ]
  end

  test "MEX catalog with an unmapped EPA model gets no USA row" do
    apps, = resolve_usa(application(manufacturer: "Nissan", model: "Estaquitas", year: 1993, liters: 2.4, cylinders: 4, market: "MEX"))

    assert_equal [ "MEX" ], apps.map(&:market)
  end

  test "a confirm_only model keeps the row and records difiere (D22)" do
    apps, validations = resolve_usa(application(manufacturer: "Chevrolet", model: "Express 2500", year: 2007, liters: 6.0, cylinders: 8, market: "USA"))

    assert_equal [ "USA" ], apps.map(&:market)
    assert_not epa_evidence?(apps.first)
    assert_equal [ "difiere" ], validations.select { _1.field == "Motor" }.map(&:status)
    assert_includes validations.map { [ _1.source_value, _1.status ] }, [ "USA · Chevrolet Express 2500 2007", "según catálogo" ]
  end

  test "a reviewed exception keeps only its engine (D22)" do
    kept, = resolve_usa(application(manufacturer: "Cadillac", model: "CTS", year: 2009, liters: 6.2, cylinders: 8, market: "USA"))
    removed, = resolve_usa(application(manufacturer: "Cadillac", model: "CTS", year: 2009, liters: 6.0, cylinders: 8, market: "USA"))

    assert_equal [ "USA" ], kept.map(&:market)
    assert_empty removed
  end

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
