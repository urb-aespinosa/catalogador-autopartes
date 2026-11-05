require "test_helper"

class Sources::SafetyTest < ActiveSupport::TestCase
  BASE = "https://www.safetyautoparts.com/webcatalog".freeze
  VPIC = "https://vpic.nhtsa.dot.gov/api/vehicles".freeze

  setup do
    %w[GMT GMC].each { stub_source("#{BASE}/tradengines.php?MakeCode=#{_1}", "safety/tradengines_#{_1}.html") }
    Dir.children(file_fixture("sources/safety")).grep(/\Atradappresults_/).each do |name|
      code = name[/tradappresults_(.+)\.html/, 1]
      stub_source("#{BASE}/tradappresults.php?EngineCode=#{code}", "safety/#{name}")
    end
    stub_source("#{VPIC}/GetModelsForMake/Chevrolet?format=json", "vpic/models_chevrolet.json", content_type: "application/json")
    stub_source("#{VPIC}/GetModelsForMake/GMC?format=json", "vpic/models_gmc.json", content_type: "application/json")
  end

  def safety = Sources::Safety.new
  def item(part_number) = SourceItem.new(part_number: part_number, manufacturer: "SAFETY")
  def hints = Catalog::DescriptionParser.call("83-301 CHEVROLET SILVERADO V6 262 4.3 INC ECOTEC 12 VAL 14/18")
  def result = @result ||= safety.call(item: item("SP26-329R/L+20"), hints: hints)

  test "applications per model with the real make, never GM" do
    rows = result.applications.map { [ _1.manufacturer, _1.model, _1.year ] }

    assert_equal :found, result.status
    assert_includes rows, [ "Chevrolet", "Silverado", 2014 ]
    assert_includes rows, [ "Chevrolet", "Silverado", 2021 ]
    assert_includes rows, [ "GMC", "Sierra", 2021 ]
    assert_includes rows, [ "Chevrolet", "Express", 2018 ]
    assert_includes rows, [ "GMC", "Savana", 2021 ]
    refute_includes rows, [ "Chevrolet", "Express", 2017 ]
    refute rows.any? { _1.first.to_s.match?(/\AGM\z/i) || _1.first.nil? }
  end

  test "engine data comes from the engine label" do
    app = result.applications.first

    assert_equal [ 4.3, 262, 6, "V", "USA" ], [ app.liters, app.cid, app.cylinders, app.block, app.market ]
    assert_equal "#{BASE}/tradappresults.php?EngineCode=GMT-LV3", app.url
    assert_equal [ [ "identificación de marca NHTSA vPIC", "#{VPIC}/GetModelsForMake/Chevrolet?format=json" ] ], result.applications.find { _1.model == "Silverado" }.evidence_urls
    refute result.per_engine_years
  end

  test "oversize comes from the part number" do
    attr = result.attributes.find { _1.name == "Sobremedida" }

    assert_equal [ "+20", "+20", "número de parte" ], [ attr.value, attr.original, attr.origin ]
  end

  test "a part number without oversize has no oversize attribute" do
    r = safety.call(item: item("SP26-329R/L"), hints: hints)

    assert_nil r.attributes.find { _1.name == "Sobremedida" }
    assert_equal :found, r.status
  end

  test "a model without an identifiable make produces no row and a validation" do
    stub_source("#{VPIC}/GetModelsForMake/GMC?format=json", json: { "Results" => [ { "Model_Name" => "Sierra" } ] })

    r = safety.call(item: item("SP26-329R/L+20"), hints: hints)

    refute r.applications.any? { _1.model == "Savana" }
    validation = r.validations.find { _1.source_value == "Savana" }
    assert_equal [ "Fabricante", "no encontrado" ], [ validation.field, validation.status ]
  end

  test "falls back to every engine when the liters hint misses" do
    wrong_liters = Catalog::DescriptionParser.call("83-301 CHEVROLET SILVERADO V6 262 9.9 14/18")
    stub_request(:get, %r{#{Regexp.escape(BASE)}/tradappresults\.php}).to_return(body: "<table></table>")
    stub_source("#{BASE}/tradappresults.php?EngineCode=GMT-LV3", "safety/tradappresults_GMT-LV3.html")

    r = safety.call(item: item("SP26-329R/L+20"), hints: wrong_liters)

    assert_includes r.applications.map(&:model), "Silverado"
  end

  test "a part in no engine is not_found after reading every engine" do
    every_engine = stub_request(:get, %r{#{Regexp.escape(BASE)}/tradappresults\.php}).to_return(body: "<table></table>")

    assert_equal :not_found, safety.call(item: item("SP99-999"), hints: hints).status
    assert_requested every_engine, at_least_times: 100
  end

  test "an engine list without options raises ParseError" do
    stub_source("#{BASE}/tradengines.php?MakeCode=GMT", body: "<html>error</html>")

    assert_raises(Sources::ParseError) { result }
  end

  test "registry maps SAFETY" do
    assert_instance_of Sources::Safety, Sources::Registry.for("SAFETY")
  end
end
