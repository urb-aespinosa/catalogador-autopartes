require "test_helper"

# The evaluator's rule: the same dataset run twice must give the same result.
# Workbook contents are compared cell by cell (not the .xlsx bytes, which carry
# a creation timestamp).
class DeterminismTest < ActiveSupport::TestCase
  setup { stub_all_sources_from_fixtures }

  def export(name)
    path = Rails.root.join("tmp/determinism_#{name}_#{Process.pid}.xlsx")
    Catalog::WorkbookExporter.call(Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx")), path)
    workbook_rows(path).tap { FileUtils.rm_f(path) }
  end

  test "two runs over the same input produce identical workbook contents" do
    first = export("a")
    second = export("b")

    assert_equal first, second
    assert first["Aplicaciones"].size > 1
    # The reader tells a real formula from the text "=B4-B5", so a run that
    # stored formulas as text would not compare equal to one that did not.
    assert_includes first["Métricas"].flatten, WorkbookReader::Formula.new("B4-B5")
  end
end
