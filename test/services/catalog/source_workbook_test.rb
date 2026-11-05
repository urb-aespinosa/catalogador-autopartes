require "test_helper"

class Catalog::SourceWorkbookTest < ActiveSupport::TestCase
  test "reads the five source rows in order" do
    rows = Catalog::SourceWorkbook.read(file_fixture("data_prueba_tecnica.xlsx"))

    assert_equal %w[FSX-5840301 HL-7025S RM-152 SP26-329R/L+20 TK1283-1], rows.map { _1[:part_number] }
    assert_equal "6536", rows.first[:internal_code]
    assert_equal "QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03", rows.first[:description]
    assert_equal "JUEGO DE EMPAQUES", rows.first[:item_group]
    assert_equal "JUEGO", rows.first[:unit]
    assert_equal "REVO", rows.last[:manufacturer]
    assert_equal (0..4).to_a, rows.map { _1[:position] }
  end

  test "skips blank trailing rows" do
    rows = Catalog::SourceWorkbook.read(file_fixture("ejemplo_prueba_tecnica.xlsx"))

    assert_equal 10, rows.size
  end

  test "rejects a workbook without an Origen sheet" do
    path = Rails.root.join("tmp/no_origen.xlsx")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Hoja1") { |sheet| sheet.add_row %w[a b] }
    package.serialize(path.to_s)

    error = assert_raises(Catalog::SourceWorkbook::InvalidFile) { Catalog::SourceWorkbook.read(path) }
    assert_match "hoja Origen", error.message
  end

  test "rejects a workbook whose Origen sheet lacks the expected columns" do
    path = Rails.root.join("tmp/bad_columns.xlsx")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: "Origen") { |sheet| sheet.add_row %w[foo bar] }
    package.serialize(path.to_s)

    error = assert_raises(Catalog::SourceWorkbook::InvalidFile) { Catalog::SourceWorkbook.read(path) }
    assert_match "Número de parte", error.message
  end

  test "rejects a non-xlsx file" do
    assert_raises(Catalog::SourceWorkbook::InvalidFile) do
      Catalog::SourceWorkbook.read(file_fixture("not_excel.txt"))
    end
  end
end
