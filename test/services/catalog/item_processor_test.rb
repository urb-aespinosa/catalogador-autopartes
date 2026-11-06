require "test_helper"

class Catalog::ItemProcessorTest < ActiveSupport::TestCase
  # Stands in for an interchange brand's adapter (e.g. Melling) in tests.
  class FakeInterchangeSource < Sources::Base
    def call(item:, hints:)
      Sources::Result.found(
        market: "USA",
        applications: [ application(manufacturer: "NISSAN", model: "Pickup", year: 1990, market: "USA", url: "https://brand/#{item.part_number}") ],
        attributes: [ attribute(name: "Material", value: "Steel", url: "https://brand") ]
      )
    end
  end

  class BrokenSource < Sources::Base
    def call(item:, hints:) = nil.fetch("models")
  end

  class FailingInterchangeSource < Sources::Base
    def call(item:, hints:) = raise(Catalog::Fetcher::SourceError.new(url: "https://brand/x", detail: "timeout después de 15 s"))
  end

  BrokenRegistry = Struct.new(:adapter) do
    def for(_manufacturer) = adapter.new
  end

  setup { stub_all_sources_from_fixtures }

  def source_item(**values)
    run = Run.create!
    run.source_items.create!(position: 0, part_number: "X", **values)
  end

  def process(item, **options) = Catalog::ItemProcessor.new(item, **options).call

  # D18: "no encontrado" means the source was searched and the part was not
  # there; a manufacturer with no adapter was never searched.
  test "a manufacturer without official source: no rows, product from the ERP group, sin fuente configurada" do
    item = source_item(manufacturer: "REVO", item_group: "KIT DE DISTRIBUCION", part_number: "TK1283-1", unit: "JUEGO",
                       description: "9-0511S SA-76260 DDM-77020 CHRYSLER DURANGO JOURNEY V6 3.6 SOHC 24 VAL PENTASTAR 11/13")

    r = process(item)

    assert_equal "KIT DE DISTRIBUCIÓN", r.product
    assert_empty r.applications
    source_rows = r.validations.select { _1.field == "Fuente" }.map { [ _1.erp_value, _1.source_value, _1.status ] }
    assert_equal [ [ "REVO", nil, "sin fuente configurada" ] ], source_rows
    # The hint rows (Armadora, Años, Intercambio…) were not searched either.
    assert_operator r.validations.size, :>, 1
    assert_equal [ "sin fuente configurada" ], r.validations.map(&:status).uniq
    assert_equal [ "no_source", "KIT DE DISTRIBUCIÓN" ], [ item.reload.status, item.product ]
    assert_equal "sin fuente configurada", SourceItem::STATUS_LABELS.fetch(item.status)
    assert_equal r, Catalog::Records::ItemResult.from_h(item.result)
  end

  test "a configured source that does not have the part stays no encontrado" do
    item = source_item(manufacturer: "ELGIN", item_group: "BOMBA DE ACEITE", part_number: "ZZ-0000", unit: "PIEZA", description: "")
    adapter = Struct.new(:result) { def call(**) = result }.new(Sources::Result.not_found(market: "MEX"))
    registry = Struct.new(:adapter) { def for(_) = adapter }.new(adapter)

    r = process(item, registry: registry)

    assert_equal [ [ "Fuente", "no encontrado" ] ], r.validations.select { _1.field == "Fuente" }.map { [ _1.field, _1.status ] }
    assert_equal "not_found", item.reload.status
  end

  test "a source error is recorded as error de fuente and does not raise" do
    stub_request(:get, /catalog\.elginind\.com/).to_timeout
    item = source_item(manufacturer: "ELGIN", part_number: "HL-7025S", item_group: "PUNTERIAS", description: "HL7011 CHEVROLET V8 99/23")

    r = process(item)

    fuente = r.validations.find { _1.field == "Fuente" }
    assert_equal "error de fuente", fuente.status
    assert_match "timeout", fuente.source_value
    assert_match "catalog.elginind.com", fuente.url
    assert_equal "error", item.reload.status
  end

  test "a changed page is recorded as error de fuente" do
    stub_source("#{SourceStubs::ELGIN}/engine/part/#{SourceStubs::ELGIN_PART}/", body: "<html>mantenimiento</html>")
    item = source_item(manufacturer: "ELGIN", part_number: "HL-7025S", item_group: "PUNTERIAS")

    assert_equal "error de fuente", process(item).validations.find { _1.field == "Fuente" }.status
  end

  test "an unexpected adapter error is recorded as error de fuente and does not raise" do
    item = source_item(manufacturer: "ELGIN", part_number: "HL-7025S", item_group: "PUNTERIAS")

    r = process(item, registry: BrokenRegistry.new(BrokenSource))

    fuente = r.validations.find { _1.field == "Fuente" }
    assert_equal "error de fuente", fuente.status
    assert_match "NoMethodError", fuente.source_value
    assert_equal "error", item.reload.status
  end

  test "a failed interchange complement is reported without demoting the part" do
    confirmed = [ { "part" => "RM-152", "number" => "M152", "brand" => "Melling", "adapter" => "Failing", "url" => "https://melling/confirm" } ]
    item = source_item(manufacturer: "REXITE", part_number: "RM-152", item_group: "BOMBA DE ACEITE", unit: "PZA")

    r = process(item, interchanges: confirmed, adapters: { "Failing" => FailingInterchangeSource })

    assert_equal "done", item.reload.status
    assert_equal [ "oficial" ], r.applications.map(&:origin).uniq
    assert_includes r.validations.map { [ _1.field, _1.status, _1.url ] }, [ "Fuente", "error de fuente", "https://brand/x" ]
  end

  test "end to end over fixtures for HL-7025S" do
    item = source_item(manufacturer: "ELGIN", part_number: "HL-7025S", item_group: "PUNTERIAS", unit: "PZA",
                       description: "HL7011 CHEVROLET V8 294 4.3 VORTEC 325 5.3 LS1 , 6.0 6.2 VORTEC 16 VAL 99/23 CON RESORTE")

    r = process(item)

    assert_equal "JUEGO DE PUNTERÍAS DE MOTOR", r.product
    assert r.applications.any?
    assert r.applications.all? { _1.year.is_a?(Integer) && _1.years.nil? && _1.market == "USA" }
    assert r.applications.all? { _1.evidence_urls.any? { |origin, _| origin == "verificación NHTSA vPIC" } }
    assert_includes r.validations.map { [ _1.field, _1.status ] }, [ "Unidad", "difiere" ]
    assert_includes r.validations.map(&:field), "Modelo-año"
    assert_equal "done", item.reload.status
  end

  test "a confirmed interchange adds applications marked vía intercambio, never its attributes" do
    confirmed = [ { "part" => "RM-152", "number" => "M152", "brand" => "Melling", "adapter" => "FakeInterchange", "url" => "https://melling/confirm" } ]
    item = source_item(manufacturer: "REXITE", part_number: "RM-152", item_group: "BOMBA DE ACEITE", unit: "PZA",
                       description: "DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14")

    r = process(item, interchanges: confirmed, adapters: { "FakeInterchange" => FakeInterchangeSource })

    complement = r.applications.find { _1.model == "Pickup" }
    assert_equal [ "vía intercambio de M152 (Melling)", "USA", "https://brand/M152" ], [ complement.origin, complement.market, complement.url ]
    assert_includes r.applications.map(&:origin), "oficial"
    assert_empty r.attributes
    interchange = r.interchanges.find { _1.number == "M152" }
    assert_equal [ "Melling", "Aftermarket", "https://melling/confirm" ], [ interchange.brand, interchange.kind, interchange.url ]
  end

  test "an unconfirmed interchange is not used" do
    item = source_item(manufacturer: "REXITE", part_number: "RM-152", item_group: "BOMBA DE ACEITE", unit: "PZA",
                       description: "DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14")

    r = process(item)

    assert_equal [ "oficial" ], r.applications.map(&:origin).uniq
    assert_empty r.interchanges
    assert_includes r.validations.map { [ _1.field, _1.erp_value, _1.status ] }, [ "Intercambio", "DM-152", "no encontrado" ]
  end

  test "pipeline runs every item of a workbook synchronously" do
    run = Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx"))

    assert_equal "processing", run.reload.status
    assert_equal %w[done done done done no_source], run.source_items.map(&:status)
  end
end
