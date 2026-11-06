require "test_helper"

class Sources::RexiteTest < ActiveSupport::TestCase
  SEARCH = "https://rexite.net/wp-json/wc/store/v1/products?search=%s".freeze

  setup do
    stub_source(format(SEARCH, "RM-152"), "rexite/search_RM-152.json", content_type: "application/json")
  end

  def rexite = Sources::Rexite.new
  def item(part_number) = SourceItem.new(part_number: part_number, manufacturer: "REXITE")

  test "RM-152 official application is the 280ZX 81-82" do
    r = rexite.call(item: item("RM-152"), hints: nil)

    assert_equal :found, r.status
    assert_equal [ [ "Nissan", "280ZX", 1981 ], [ "Nissan", "280ZX", 1982 ] ], r.applications.map { [ _1.manufacturer, _1.model, _1.year ] }
    app = r.applications.first
    assert_equal [ 2.8, 6, "L", "MEX" ], [ app.liters, app.cylinders, app.block, app.market ]
    assert_equal "https://rexite.net/producto/bomba-de-aceite-rm-152-nissan/", app.url
    assert_equal "Nissan 280Zx 1981", app.original
    assert_equal "MEX", r.market
    refute r.per_engine_years
  end

  test "a search hit with a different sku is not_found" do
    stub_source(format(SEARCH, "RM-999"), json: [ { "sku" => "RM-9990", "attributes" => [] } ])

    assert_equal :not_found, rexite.call(item: item("RM-999"), hints: nil).status
  end

  test "an empty search is not_found" do
    stub_source(format(SEARCH, "RM-998"), json: [])

    assert_equal :not_found, rexite.call(item: item("RM-998"), hints: nil).status
  end

  test "a product without compatibility data raises ParseError" do
    stub_source(format(SEARCH, "RM-997"), json: [ { "sku" => "RM-997", "permalink" => "https://rexite.net/x", "attributes" => [] } ])

    assert_raises(Sources::ParseError) { rexite.call(item: item("RM-997"), hints: nil) }
  end

  test "a response that is not a product list raises ParseError" do
    stub_source(format(SEARCH, "RM-996"), json: { "code" => "rest_no_route" })

    assert_raises(Sources::ParseError) { rexite.call(item: item("RM-996"), hints: nil) }
  end

  test "a product with several engines does not pin one engine to every row" do
    product = {
      "sku" => "RM-995", "permalink" => "https://rexite.net/y",
      "attributes" => [
        { "name" => "Marcas", "terms" => [ { "name" => "Nissan" } ] },
        { "name" => "Compatible", "terms" => [ { "name" => "Nissan Pickup 1990" } ] },
        { "name" => "Litros", "terms" => [ { "name" => "2.0" }, { "name" => "2.4" } ] },
        { "name" => "Cilindros", "terms" => [ { "name" => "4" } ] },
        { "name" => "Motores", "terms" => [ { "name" => "2.0L 4Cyl L" }, { "name" => "2.4L 4Cyl L" } ] }
      ]
    }
    stub_source(format(SEARCH, "RM-995"), json: [ product ])

    app = rexite.call(item: item("RM-995"), hints: nil).applications.first

    assert_equal [ nil, 4, "L" ], [ app.liters, app.cylinders, app.block ]
  end

  test "a product whose attributes are null raises ParseError" do
    stub_source(format(SEARCH, "RM-994"), json: [ { "sku" => "RM-994", "permalink" => "https://rexite.net/z", "attributes" => nil } ])

    assert_raises(Sources::ParseError) { rexite.call(item: item("RM-994"), hints: nil) }
  end

  test "registry maps REXITE" do
    assert_instance_of Sources::Rexite, Sources::Registry.for("REXITE")
  end
end
