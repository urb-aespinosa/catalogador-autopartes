# Reads a workbook's content (not its bytes) so two exports can be compared:
# { "Sheet name" => [[row values], ...] }. Formula cells read as their formula.
module WorkbookReader
  def workbook_rows(path)
    book = Roo::Excelx.new(path.to_s, extension: :xlsx)
    book.sheets.to_h do |name|
      sheet = book.sheet(name)
      rows = (1..sheet.last_row.to_i).map do |r|
        (1..sheet.last_column.to_i).map { |c| sheet.formula?(r, c) ? "=#{sheet.formula(r, c)}" : sheet.cell(r, c) }
      end
      [ name, rows ]
    end
  end

  def sheet_names(path) = Roo::Excelx.new(path.to_s, extension: :xlsx).sheets
end
