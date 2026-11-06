require "test_helper"

class RunTest < ActiveSupport::TestCase
  test "create_from_upload! attaches the input and creates one item per row" do
    run = File.open(file_fixture("data_prueba_tecnica.xlsx")) do |io|
      Run.create_from_upload!(io, "data_prueba_tecnica.xlsx")
    end

    assert run.input.attached?
    assert_equal "pending", run.status
    assert_equal %w[FSX-5840301 HL-7025S RM-152 SP26-329R/L+20 TK1283-1], run.source_items.map(&:part_number)
    assert run.source_items.all? { _1.status == "pending" && _1.result == {} }
  end

  test "create_from_upload! with an invalid file raises and creates nothing" do
    assert_no_difference -> { Run.count } do
      assert_raises(Catalog::SourceWorkbook::InvalidFile) do
        File.open(file_fixture("not_excel.txt")) { |io| Run.create_from_upload!(io, "not_excel.txt") }
      end
    end
  end
end
