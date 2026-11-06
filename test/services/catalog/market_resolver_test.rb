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

  FUELS = { "Regular" => "Gasolina", "Premium" => "Gasolina", "Gasoline or E85 (FFV)" => "Flex", "Diesel" => "Diésel" }.freeze

  def fuel_epa
    Catalog::Epa.new(
      models: { "Chevrolet" => { "Silverado 1500" => [ "Silverado C15 2WD" ] }, "Nissan" => { "D21" => [ "Truck 2WD" ] } },
      rows: [
        vehicle(2015, "Chevrolet", "Silverado C15 2WD", 4.3, 6, "Regular"),
        vehicle(2015, "Chevrolet", "Silverado C15 2WD", 6.2, 8, "Premium"),
        vehicle(2016, "Chevrolet", "Silverado C15 2WD", 5.3, 8, "Regular"),
        { **vehicle(2016, "Chevrolet", "Silverado C15 2WD", 5.3, 8, "Gasoline or E85"), "id" => "99", "atvType" => "FFV" },
        { **vehicle(2014, "Chevrolet", "Silverado C15 2WD", 4.3, 6, "Regular"), "atvType" => "Hybrid" },
        vehicle(1993, "Nissan", "Truck 2WD", 2.4, 4, "Regular")
      ]
    )
  end

  def resolve_fuel(*apps) = Catalog::MarketResolver.call(apps, inegi: inegi, epa: fuel_epa, fuels: FUELS)

  def silverado(year, liters, cylinders, fuel: nil)
    application(manufacturer: "Chevrolet", model: "Silverado 1500", year: year, liters: liters, cylinders: cylinders, fuel: fuel, market: "USA")
  end

  test "a single EPA fuel fills the USA row only" do
    apps, = resolve_fuel(silverado(2015, 4.3, 6))

    mex, usa = apps.partition { _1.market == "MEX" }.map(&:sole)
    assert_equal "Gasolina", usa.fuel
    assert_nil mex.fuel
    assert_includes usa.evidence_urls, [ "combustible: EPA fueleconomy.gov",
                                         "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2015&make=Chevrolet&model=Silverado%20C15%202WD" ]
  end

  test "several EPA fuels leave it empty with the list in Fuentes" do
    apps, = resolve_fuel(silverado(2016, 5.3, 8))

    usa = apps.find { _1.market == "USA" }
    assert_nil usa.fuel
    assert_includes usa.evidence_urls, [ "combustible: EPA fueleconomy.gov",
                                         "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2016&make=Chevrolet&model=Silverado%20C15%202WD",
                                         "combustibles EPA: Gasoline or E85 (FFV), Regular" ]
  end

  test "a catalog fuel is kept and a different EPA fuel is recorded as difiere" do
    apps, validations = resolve_fuel(silverado(2015, 4.3, 6, fuel: "Diésel"))

    assert_equal "Diésel", apps.find { _1.market == "USA" }.fuel
    assert_equal [ [ nil, "catálogo: Diésel · EPA: Gasolina · https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2015&make=Chevrolet&model=Silverado%20C15%202WD", "difiere" ] ],
                 validations.select { _1.field == "Combustible" }.map { [ _1.erp_value, _1.source_value, _1.status ] }
  end

  test "a USA catalog fuel never reaches the MEX row" do
    apps, = resolve_fuel(silverado(2015, 4.3, 6, fuel: "Gasolina"))

    assert_nil apps.find { _1.market == "MEX" }.fuel
    assert_equal "Gasolina", apps.find { _1.market == "USA" }.fuel
  end

  test "a MEX catalog fuel stays on the MEX row; the USA row takes EPA's" do
    apps, = resolve_fuel(application(manufacturer: "Nissan", model: "D21", year: 1993, liters: 2.4, cylinders: 4, fuel: "Diésel", market: "MEX"))

    assert_equal [ [ "MEX", "Diésel" ], [ "USA", "Gasolina" ] ], apps.map { [ _1.market, _1.fuel ] }
  end

  test "EPA fuels reuse the spellings fuels.yml already has for other sources" do
    epa_keys = [ "Regular", "Premium", "Gasoline or E85 (FFV)", "Diesel", "Diesel (Diesel)", "CNG (CNG)" ]
    fuels = Catalog::Normalizer::FUELS

    assert_empty epa_keys - fuels.keys
    assert_empty epa_keys.map { fuels[_1] } - fuels.except(*epa_keys).values
    assert_empty fuels.keys.grep(/Hybrid|Electricity|Bifuel/)
  end

  test "an unknown EPA fuel is not guessed" do
    apps, validations = resolve_fuel(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2014, liters: 4.3, cylinders: 6, market: "USA"))

    assert_nil apps.find { _1.market == "USA" }.fuel
    assert_includes validations.map { [ _1.field, _1.source_value, _1.status ] }, [ "Traducción", "Regular (Hybrid)", "sin traducción" ]
  end

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
    assert motor.first.source_value.end_with?(" · eliminada")
    assert_empty validations.select { _1.field == "Mercado" }
  end

  test "MEX catalog engine refuted by EPA keeps MEX and denies USA" do
    apps, validations = resolve_usa(application(manufacturer: "Nissan", model: "D21", year: 1993, liters: 2.4, cylinders: 4, market: "MEX"))

    assert_equal [ "MEX" ], apps.map(&:market)
    motor = validations.select { _1.field == "Motor" }
    assert_equal [ "difiere" ], motor.map(&:status)
    assert motor.first.source_value.end_with?(" · se conserva solo MEX")
  end

  test "an engine only half known is not verified, never refuted (Review Focus 1)" do
    liters_only, v1 = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2010, liters: 6.0, cylinders: nil, market: "USA"))
    cylinders_only, v2 = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2010, liters: nil, cylinders: 10, market: "USA"))

    assert epa_evidence?(liters_only.find { _1.market == "USA" })
    assert epa_evidence?(cylinders_only.find { _1.market == "USA" })
    assert_empty (v1 + v2).select { _1.field == "Motor" }
  end

  test "a name vPIC never lists gets no USA row even when EPA maps it (D20)" do
    apps, = resolve_usa(application(manufacturer: "Chevrolet", model: "Silverado 1500", year: 2015, liters: 4.3, cylinders: 6, market: "USA", vpic_unknown: true))

    assert_equal [ "MEX" ], apps.map(&:market)
  end

  test "MEX catalog with an EPA engine match also gets a USA row at level a" do
    apps, validations = resolve_usa(application(manufacturer: "Nissan", model: "D21", year: 1993, liters: 3.0, cylinders: 6, market: "MEX"))

    assert_equal [ "MEX", "USA" ], apps.map(&:market)
    assert epa_evidence?(apps.last)
    assert_includes validations.map { [ _1.source_value, _1.status ] }, [ "USA · Nissan D21 1993", "confirmado por EPA" ]
  end

  test "a model vPIC knows is not rescued by INEGI sales in an unconfirmed year (D20)" do
    stub_source("https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMakeYear/make/Chevrolet/modelyear/2020?format=json",
                "vpic/models_chevrolet_2020.json", content_type: "application/json")
    stub_source("https://vpic.nhtsa.dot.gov/api/vehicles/GetModelsForMake/Chevrolet?format=json",
                "vpic/models_chevrolet.json", content_type: "application/json")
    rows, vpic_validations = Catalog::Vpic.expand([ application(manufacturer: "CHEVROLET", model: "Avalanche", years: 2020..2020, market: "USA") ])
    sold = Catalog::InegiSales.new(models: { "CHEVROLET" => { "Avalanche" => [ { "marca" => GM, "modelo" => "Avalanche UUV" } ] } },
                                   rows: [ sale(2020, GM, "Avalanche UUV", 3) ])

    apps, = Catalog::MarketResolver.call(rows, inegi: sold, epa: nil)

    assert_empty apps
    assert_equal [ "Chevrolet Avalanche 2020" ], vpic_validations.map(&:source_value)
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
    motor = validations.select { _1.field == "Motor" }
    assert_equal [ "difiere" ], motor.map(&:status)
    assert motor.first.source_value.end_with?(" · se conserva (confirm_only)")
    assert_includes validations.map { [ _1.source_value, _1.status ] }, [ "USA · Chevrolet Express 2500 2007", "según catálogo" ]
  end

  test "a reviewed exception keeps only its engine (D22)" do
    kept, kept_validations = resolve_usa(application(manufacturer: "Cadillac", model: "CTS", year: 2009, liters: 6.2, cylinders: 8, market: "USA"))
    removed, removed_validations = resolve_usa(application(manufacturer: "Cadillac", model: "CTS", year: 2009, liters: 6.0, cylinders: 8, market: "USA"))

    assert_equal [ "USA" ], kept.map(&:market)
    assert kept_validations.find { _1.field == "Motor" }.source_value.end_with?(" · se conserva (excepción revisada)")
    assert_empty removed
    assert removed_validations.find { _1.field == "Motor" }.source_value.end_with?(" · eliminada")
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
