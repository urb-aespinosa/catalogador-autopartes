require "test_helper"
require "rake"

class CatalogRunTaskTest < ActiveSupport::TestCase
  setup do
    stub_all_sources_from_fixtures
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @output = Rails.root.join("tmp/catalog_run_test_#{Process.pid}.xlsx")
  end

  teardown { FileUtils.rm_f(@output) }

  test "catalog:run writes the workbook for an input file" do
    Rake::Task["catalog:run"].reenable
    assert_output(/Catálogo generado/) do
      Rake::Task["catalog:run"].invoke(file_fixture("data_prueba_tecnica.xlsx").to_s, @output.to_s)
    end

    assert File.exist?(@output)
    assert_equal 5, workbook_rows(@output)["Catálogo"].size - 1
  end
end
