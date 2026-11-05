require "test_helper"

class Sources::FracoTest < ActiveSupport::TestCase
  URL = "https://www.fraco.com.mx/QRMX/%s.pdf".freeze

  setup do
    %w[FSX-5840301 FSX-5840299].each do |part|
      stub_source(format(URL, part), "fraco/#{part}.pdf", content_type: "application/pdf")
    end
  end

  def fraco = Sources::Fraco.new
  def item(part_number) = SourceItem.new(part_number: part_number, manufacturer: "FRACO")
  def value_of(result, name) = result.attributes.find { _1.name == name }&.value

  test "FSX-5840301 models and years come from the PDF table" do
    r = fraco.call(item: item("FSX-5840301"), hints: nil)
    pairs = r.applications.map { [ _1.model, _1.year ] }

    assert_equal :found, r.status
    assert_includes pairs, [ "D21", 1990 ]
    assert_includes pairs, [ "D21", 1994 ]
    refute_includes pairs, [ "D21", 1995 ]
    assert_includes pairs, [ "Silvia", 1989 ]
    assert_includes pairs, [ "Pickup", 1997 ]
    assert_includes pairs, [ "Estaquitas", 1991 ]
    assert_includes pairs, [ "Terrano", 1999 ]
    assert_equal %w[D21 Estaquitas Ichivan Pickup Silvia Stanza Terrano], pairs.map(&:first).uniq.sort
  end

  test "FSX-5840301 engine data and market" do
    app = fraco.call(item: item("FSX-5840301"), hints: nil).applications.first

    assert_equal [ "NISSAN", 2.4, 2389, 146, 4, "L", "MEX" ], [ app.manufacturer, app.liters, app.cc, app.cid, app.cylinders, app.block, app.market ]
    assert_equal format(URL, "FSX-5840301"), app.url
    assert_nil app.years
    assert_nil app.fuel
  end

  test "FSX-5840301 attributes" do
    r = fraco.call(item: item("FSX-5840301"), hints: nil)

    assert_equal "12", value_of(r, "Número de válvulas")
    assert_equal "89", value_of(r, "Diámetro")
    assert_equal "mm", r.attributes.find { _1.name == "Diámetro" }.unit
    assert_equal "96", value_of(r, "Carrera")
    assert_equal "SB", value_of(r, "Junta Cabeza")
    assert_equal false, r.per_engine_years
    assert_equal "MEX", r.market
  end

  test "control part FSX-5840299 matches the evaluator example" do
    r = fraco.call(item: item("FSX-5840299"), hints: nil)

    assert_equal [ "16", "89", "MLO" ], [ "Número de válvulas", "Diámetro", "Junta Cabeza" ].map { value_of(r, _1) }
    assert_equal 2488, r.applications.first.cc
    assert_equal 153, r.applications.first.cid
    assert_equal [ "NP 300 Frontier", "NP300", "Nv350 Urvan" ], r.applications.map(&:model).uniq.sort
    assert_equal (2016..2019).to_a, r.applications.select { _1.model == "NP300" }.map(&:year)
    assert_equal (2013..2019).to_a, r.applications.select { _1.model == "Nv350 Urvan" }.map(&:year)
  end

  test "a missing sheet (404) is not_found" do
    stub_source(format(URL, "FSX-0000000"), status: 404)

    assert_equal :not_found, fraco.call(item: item("FSX-0000000"), hints: nil).status
  end

  test "other HTTP errors are not swallowed" do
    stub_source(format(URL, "FSX-0000001"), status: 500)

    assert_raises(Catalog::Fetcher::SourceError) { fraco.call(item: item("FSX-0000001"), hints: nil) }
  end

  test "a PDF without the model table raises ParseError" do
    stub_source(format(URL, "FSX-0000002"), body: "%PDF-1.4 not really a pdf", content_type: "application/pdf")

    assert_raises(Sources::ParseError) { fraco.call(item: item("FSX-0000002"), hints: nil) }
  end

  test "part numbers are escaped in the URL" do
    stub = stub_source("https://www.fraco.com.mx/QRMX/A%2FB%2B1.pdf", status: 404)

    fraco.call(item: item("A/B+1"), hints: nil)

    assert_requested stub
  end

  test "registry maps FRACO" do
    assert_instance_of Sources::Fraco, Sources::Registry.for("FRACO")
  end
end
