require "test_helper"

class Catalog::InegiSalesTest < ActiveSupport::TestCase
  GM = "General Motors".freeze

  def sale(year, month, model, units, make: GM)
    { "ANIO" => year.to_s, "ID_MES" => format("%02d", month), "MARCA" => make, "MODELO" => model, "UNI_VEH" => units.to_s }
  end

  def models
    {
      "Chevrolet" => { "Silverado 1500" => [ { "marca" => GM, "modelo" => "Silverado 1500 Cabina Regular" } ],
                       "Cheyenne" => [ { "marca" => GM, "modelo" => "Cheyenne Doble Cabina" } ] },
      "GMC" => { "Sierra 1500" => [ { "marca" => GM, "modelo" => "Sierra 1500" } ] }
    }
  end

  def inegi(*rows) = Catalog::InegiSales.new(rows: rows, models: models)

  test "sums the twelve months and keeps only positive totals" do
    sales = inegi(sale(2016, 1, "Silverado 1500 Cabina Regular", 3), sale(2016, 2, "Silverado 1500 Cabina Regular", 0),
                  sale(2017, 1, "Silverado 1500 Cabina Regular", 0), sale(2017, 2, "Silverado 1500 Cabina Regular", 0))

    assert_equal [ [ "Silverado 1500 Cabina Regular", 3 ] ], sales.sales(make: "Chevrolet", model: "Silverado 1500", year: 2016)
    assert_equal [], sales.sales(make: "Chevrolet", model: "Silverado 1500", year: 2017)
  end

  test "the sale must be in the same calendar year as the model year" do
    sales = inegi(sale(2015, 12, "Silverado 1500 Cabina Regular", 40))

    assert_equal [], sales.sales(make: "Chevrolet", model: "Silverado 1500", year: 2016)
  end

  test "names match after collapsing repeated and edge spaces" do
    sales = inegi(sale(2019, 3, "Cheyenne  Doble Cabina ", 7))

    assert_equal [ [ "Cheyenne Doble Cabina", 7 ] ], sales.sales(make: "Chevrolet", model: "Cheyenne", year: 2019)
  end

  test "General Motors rows only count for the make that maps them" do
    sales = inegi(sale(2016, 1, "Silverado 1500 Cabina Regular", 9))

    assert_equal [], sales.sales(make: "GMC", model: "Sierra 1500", year: 2016)
    assert_not sales.mapped?(make: "GMC", model: "Silverado 1500")
  end

  test "an unmapped model has no sales and is not mapped" do
    sales = inegi(sale(2016, 1, "Silverado 1500 Cabina Regular", 9))

    assert_not sales.mapped?(make: "Chevrolet", model: "Express 2500")
    assert sales.mapped?(make: "Chevrolet", model: "Silverado 1500")
    assert_equal [], sales.sales(make: "Chevrolet", model: "Express 2500", year: 2016)
  end

  test "the default instance reads the committed extract and the reviewed equivalences" do
    assert_equal "https://www.inegi.org.mx/datosprimarios/iavl/", Catalog::InegiSales::SOURCE_URL
    assert_kind_of Catalog::InegiSales, Catalog::InegiSales.default
  end
end
