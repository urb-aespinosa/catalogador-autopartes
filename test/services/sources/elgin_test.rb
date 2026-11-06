require "test_helper"

class Sources::ElginTest < ActiveSupport::TestCase
  BASE = "https://catalog.elginind.com".freeze
  PART_UUID = "41add5cf-f231-4fc7-8d33-1ff2b890cb08".freeze

  setup do
    stub_source("#{BASE}/part-autocomplete/?q=HL-7025S", "elgin/autocomplete_HL-7025S.json", content_type: "application/json")
    stub_source("#{BASE}/engine/part/#{PART_UUID}/", "elgin/part_HL-7025S.html")
    stub_source("#{BASE}/engine/part/#{PART_UUID}/?page=2", "elgin/part_HL-7025S_page2.html")
    Dir.children(file_fixture("sources/elgin/engines")).each do |name|
      make, uuid = File.basename(name, ".html").split("_")
      stub_source("#{BASE}/engine/#{make}/lifters-tappets/#{uuid}/", "elgin/engines/#{name}")
    end
  end

  def elgin = Sources::Elgin.new
  def item(part_number) = SourceItem.new(part_number: part_number, manufacturer: "ELGIN")
  def result = @result ||= elgin.call(item: item("HL-7025S"), hints: nil)

  test "finds HL-7025S specs with original values" do
    assert_equal :found, result.status
    assert_equal :set, result.product_kind # "Package of 4 each of HL-7025"
    assert_equal [ "Length", "Lifter Type", "Material", "Maximum Outside Diameter", "Roller" ], result.attributes.map(&:name).sort

    length = result.attributes.find { _1.name == "Length" }
    assert_equal [ "3.880", "IN", "3.880 IN" ], [ length.value, length.unit, length.original ]
    assert_equal "#{BASE}/engine/part/#{PART_UUID}/", length.url
    assert_equal "Hydraulic", result.attributes.find { _1.name == "Lifter Type" }.value
  end

  test "is a USA source with per-engine year ranges" do
    assert_equal "USA", result.market
    assert result.per_engine_years
    assert_empty result.interchanges
  end

  test "reads all 29 engines across both pages" do
    assert_equal 29, result.applications.map(&:url).uniq.size
    engines = result.applications.map { [ _1.manufacturer, _1.liters, _1.cid, _1.years ] }.uniq
    assert_includes engines, [ "CHEVROLET", 6.0, 364, 2007..2020 ]
    assert_includes engines, [ "BUICK", 5.3, 325, 1999..2016 ]
  end

  test "one row per engine and model, years left unexpanded" do
    rows = result.applications.select { _1.model == "Avalanche" && _1.cid == 364 && _1.years == (2007..2020) }

    assert_equal 1, rows.size
    assert_equal 8, rows.first.cylinders
    assert rows.all? { _1.year.nil? && _1.market == "USA" && _1.origin == "oficial" }
  end

  test "an engine listing several fuels leaves Combustible empty and keeps the list as original (D15)" do
    row = result.applications.find { _1.model == "Avalanche" && _1.cid == 364 && _1.years == (2007..2020) }

    assert_nil row.fuel
    assert_includes row.original, "CNG, FLEX, FULL HYBRID EV-FLEX (FHEV), FULL HYBRID EV-GAS (FHEV), GAS"
  end

  test "an engine listing a single fuel uses it (D15)" do
    rows = result.applications.select { _1.manufacturer == "CADILLAC" && _1.cid == 364 && _1.years == (2005..2009) }

    assert rows.any?
    assert_equal [ "GAS" ], rows.map(&:fuel).uniq
  end

  test "unknown part number is not_found" do
    stub_source("#{BASE}/part-autocomplete/?q=NOPE-1", json: [])

    assert_equal :not_found, elgin.call(item: item("NOPE-1"), hints: nil).status
  end

  test "autocomplete match must be exact" do
    stub_source("#{BASE}/part-autocomplete/?q=HL-7025", json: [ { "label" => "HL-7025S", "value" => PART_UUID } ])

    assert_equal :not_found, elgin.call(item: item("HL-7025"), hints: nil).status
  end

  test "a changed page layout raises ParseError" do
    stub_source("#{BASE}/engine/part/#{PART_UUID}/", body: "<html><body>maintenance</body></html>")

    assert_raises(Sources::ParseError) { elgin.call(item: item("HL-7025S"), hints: nil) }
  end

  test "a single-year engine row is that one year" do
    page = file_fixture("sources/elgin/part_HL-7025S_page2.html").read.sub(/1999&ndash;16/, "2008")
    stub_source("#{BASE}/engine/part/#{PART_UUID}/?page=2", body: page)

    years = result.applications.map(&:years).uniq

    assert_includes years, 2008..2008
    refute years.any? { _1.last > 2030 }
  end

  test "an unreadable year cell raises ParseError" do
    page = file_fixture("sources/elgin/part_HL-7025S_page2.html").read.sub(/1999&ndash;16/, "")
    stub_source("#{BASE}/engine/part/#{PART_UUID}/?page=2", body: page)

    assert_raises(Sources::ParseError) { result }
  end

  test "placeholder values are nil, never zero" do
    name = Dir.children(file_fixture("sources/elgin/engines")).find { _1.include?("2e9a552e") }
    page = file_fixture("sources/elgin/engines/#{name}").read.sub(%r{(CID</p>\s*<p class="mb-0">)364}, '\1-')
    stub_source("#{BASE}/engine/chevrolet/lifters-tappets/2e9a552e-b502-43f0-ac8f-5e5f058ab52c/", body: page)

    rows = result.applications.select { _1.url.include?("2e9a552e") }

    assert rows.any?
    assert rows.all? { _1.cid.nil? && _1.liters == 6.0 }
  end

  test "an autocomplete response that is not a list raises ParseError" do
    stub_source("#{BASE}/part-autocomplete/?q=HL-7025S", json: { "error" => "rate limited" })

    assert_raises(Sources::ParseError) { result }
  end

  test "a part page without the engine table raises ParseError" do
    page = file_fixture("sources/elgin/part_HL-7025S.html").read.gsub(/data-label="MFR"/, 'data-label="X"')
    stub_source("#{BASE}/engine/part/#{PART_UUID}/", body: page)

    assert_raises(Sources::ParseError) { result }
  end

  test "an engine row without its details link raises ParseError" do
    page = file_fixture("sources/elgin/part_HL-7025S_page2.html").read.sub(/data-test="engine-details-link"/, "")
    stub_source("#{BASE}/engine/part/#{PART_UUID}/?page=2", body: page)

    assert_raises(Sources::ParseError) { result }
  end

  test "registry maps ELGIN to this adapter" do
    assert_instance_of Sources::Elgin, Sources::Registry.for("ELGIN")
    assert_nil Sources::Registry.for("REVO")
  end
end
