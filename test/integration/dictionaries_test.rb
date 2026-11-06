require "test_helper"

# Every term the real sources publish for the five parts must be in the
# dictionaries, so the delivered catalog has no "sin traducción" rows.
class DictionariesTest < ActiveSupport::TestCase
  setup { stub_all_sources_from_fixtures }

  def normalized(part_number, manufacturer, group, description)
    item = SourceItem.new(part_number: part_number, manufacturer: manufacturer, item_group: group, description: description)
    result = Sources::Registry.for(manufacturer).call(item: item, hints: Catalog::DescriptionParser.call(description))
    Catalog::Normalizer.call(item: item, result: result)
  end

  def untranslated(out) = out.validations.select { _1.status == "sin traducción" }.map(&:source_value).uniq

  test "Elgin terms are all translated" do
    out = normalized("HL-7025S", "ELGIN", "PUNTERIAS", "HL7011 CHEVROLET V8 294 4.3 VORTEC 325 5.3 LS1 , 6.0 6.2 VORTEC 16 VAL 99/23 CON RESORTE")

    assert_empty untranslated(out)
    assert_equal "JUEGO DE PUNTERÍAS DE MOTOR", out.product
  end

  test "Fraco terms are all translated" do
    out = normalized("FSX-5840301", "FRACO", "JUEGO DE EMPAQUES", "QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03")

    assert_empty untranslated(out)
    assert_equal [ "Nissan" ], out.applications.map(&:manufacturer).uniq
  end

  test "Rexite terms are all translated" do
    assert_empty untranslated(normalized("RM-152", "REXITE", "BOMBA DE ACEITE", "DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14"))
  end

  test "Safety terms are all translated" do
    assert_empty untranslated(normalized("SP26-329R/L+20", "SAFETY", "PISTONES", "83-301 CHEVROLET SILVERADO V6 262 4.3 INC ECOTEC 12 VAL 14/18"))
  end
end
