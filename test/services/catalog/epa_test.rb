require "test_helper"

class Catalog::EpaTest < ActiveSupport::TestCase
  def vehicle(year, make, model, id, displ, cylinders, fuel, atv = nil)
    { "year" => year.to_s, "make" => make, "model" => model, "id" => id.to_s, "displ" => displ,
      "cylinders" => cylinders, "fuelType" => fuel, "atvType" => atv }
  end

  def models
    { "Buick" => { "Allure" => [ "Lacrosse/Allure" ] },
      "Chevrolet" => { "Silverado 2500 HD" => [ "Silverado 2500 HD 2WD" ], "Silverado 1500" => [ "Silverado C15 2WD" ] } }
  end

  def confirm_only
    { "Chevrolet" => [ "Silverado 2500 HD" ] }
  end

  def confirm_only_years
    [ { "make" => "Buick", "model" => "Allure", "year" => 2006, "liters" => 5.3, "cylinders" => 8, "reason" => "EPA gap" } ]
  end

  def epa
    Catalog::Epa.new(models: models, confirm_only: confirm_only, confirm_only_years: confirm_only_years, rows: [
      vehicle(2005, "Buick", "Lacrosse/Allure", 20100, "3.8", "6", "Regular"),
      vehicle(2005, "Buick", "Lacrosse/Allure", 20099, "3.6", "6", "Premium"),
      vehicle(2006, "Buick", "Lacrosse/Allure", 21000, "5.3", "8", "Regular"),
      vehicle(2016, "Chevrolet", "Silverado C15 2WD", 36500, "5.3", "8", "Regular", "Hybrid")
    ])
  end

  test "returns every configuration of the equivalent EPA models that year" do
    configs = epa.configurations(make: "Buick", model: "Allure", year: 2005)

    assert_equal [ 20099, 20100 ], configs.map(&:id)
    assert_equal [ 3.6, 3.8 ], configs.map(&:displ)
    assert_equal [ 6, 6 ], configs.map(&:cylinders)
    assert_equal [ "Lacrosse/Allure" ], configs.map(&:model).uniq
  end

  test "nil when the model is not mapped" do
    assert_nil epa.configurations(make: "Buick", model: "Rainier", year: 2005)
  end

  test "nil when EPA has no equivalent model that year" do
    assert_nil epa.configurations(make: "Chevrolet", model: "Silverado 2500 HD", year: 2016)
    assert_nil epa.configurations(make: "Buick", model: "Allure", year: nil)
  end

  test "fuel_key includes the ATV type" do
    config = epa.configurations(make: "Chevrolet", model: "Silverado 1500", year: 2016).sole

    assert_equal "Regular (Hybrid)", config.fuel_key
    assert_equal "Premium", epa.configurations(make: "Buick", model: "Allure", year: 2005).first.fuel_key
  end

  test "options_url encodes the model" do
    assert_equal "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2005&make=Buick&model=Lacrosse%2FAllure",
                 epa.options_url(make: "Buick", year: 2005, epa_model: "Lacrosse/Allure")
  end

  test "a mapped model refutes unless it is confirm_only (D22)" do
    assert epa.refutes?(make: "Buick", model: "Allure", year: 2005, liters: 5.3, cylinders: 8)
    assert_not epa.refutes?(make: "Chevrolet", model: "Silverado 2500 HD", year: 2005, liters: 6.0, cylinders: 8)
    assert_not epa.refutes?(make: "Buick", model: "Rainier", year: 2005, liters: 5.3, cylinders: 8)
  end

  test "a reviewed exception protects only its model, year and engine (D22)" do
    assert_not epa.refutes?(make: "Buick", model: "Allure", year: 2006, liters: 5.3, cylinders: 8)
    assert_not epa.refutes?(make: "Buick", model: "Allure", year: 2006, liters: 5.33, cylinders: 8)
    assert epa.refutes?(make: "Buick", model: "Allure", year: 2006, liters: 6.0, cylinders: 8)
    assert epa.refutes?(make: "Buick", model: "Allure", year: 2007, liters: 5.3, cylinders: 8)
  end

  test "generic names of lines with HD versions EPA does not rate are confirm_only (D22 b)" do
    confirm_only = Catalog::Epa.default_confirm_only

    { "Chevrolet" => [ "Avalanche", "Express", "Silverado", "Suburban" ], "GMC" => [ "Savana", "Sierra", "Yukon XL" ] }.each do |make, models|
      models.each { assert_includes confirm_only.fetch(make), _1, "#{make} #{_1}" }
    end
  end

  test "confirm_only? tells a confirm_only model from the rest" do
    assert epa.confirm_only?(make: "Chevrolet", model: "Silverado 2500 HD")
    assert_not epa.confirm_only?(make: "Buick", model: "Allure")
  end

  test "every confirm_only entry is a mapped model" do
    models = Catalog::Epa.default_models
    names = Catalog::Epa.default_confirm_only.flat_map { |make, list| list.map { [ make, _1 ] } } +
            Catalog::Epa.default_confirm_only_years.map { [ _1.fetch("make"), _1.fetch("model") ] }

    assert_empty names.reject { |make, model| models.dig(make, model) }
    assert Catalog::Epa.default_confirm_only_years.all? { _1["reason"].present? }
  end

  test "every EPA name in the reviewed equivalences exists in the extract" do
    known = Catalog::Epa.default_rows.map { [ _1["make"], _1["model"] ] }.to_set
    mapped = Catalog::Epa.default_models.flat_map { |make, models| models.values.flatten.map { [ make, _1 ] } }.uniq

    assert_empty mapped.reject { known.include?(_1) }
  end

  test "evidence_url points at the EPA model of the first configuration" do
    configs = epa.configurations(make: "Buick", model: "Allure", year: 2005)

    assert_equal "https://www.fueleconomy.gov/ws/rest/vehicle/menu/options?year=2005&make=Buick&model=Lacrosse%2FAllure",
                 epa.evidence_url(make: "Buick", year: 2005, configurations: configs)
  end
end
