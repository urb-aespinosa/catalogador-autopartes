require "test_helper"

# The delivered workbook is reproducible: rebuilding it from the versioned
# snapshots (db/snapshots, no network) gives the same contents, sheet by sheet.
# If the code changes the catalog, this fails until docs/output is regenerated.
class DeliveredCatalogTest < ActiveSupport::TestCase
  DELIVERED = Rails.root.join("docs/output/catalogo_bonaparte.xlsx")

  setup do
    Catalog::SnapshotArchive.load(Catalog::SnapshotArchive::DEFAULT_DIR)
    @path = Rails.root.join("tmp/delivered_check_#{Process.pid}.xlsx")
  end
  teardown { FileUtils.rm_f(@path) }

  test "rebuilding from db/snapshots reproduces docs/output/catalogo_bonaparte.xlsx" do
    run = Catalog::Pipeline.run(Rails.root.join("docs/input/data_prueba_tecnica.xlsx"))
    Catalog::WorkbookExporter.call(run, @path)

    expected = workbook_rows(DELIVERED)
    actual = workbook_rows(@path)
    assert_equal expected.keys, actual.keys
    expected.each_key { |sheet| assert_equal expected[sheet], actual[sheet], sheet }
  end
end
