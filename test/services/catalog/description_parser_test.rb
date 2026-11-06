require "test_helper"

class Catalog::DescriptionParserTest < ActiveSupport::TestCase
  def parse(text) = Catalog::DescriptionParser.call(text)

  test "fraco description" do
    h = parse("QJC20G FS-001225 JC20 NISSAN PICK UP 4 CIL 2.4 KA24E SOHC 12 VAL 89/03")

    assert_equal %w[QJC20G FS-001225 JC20], h.interchanges
    assert_equal "NISSAN", h.make
    assert_equal "PICK UP", h.models_text
    assert_equal [ 4 ], h.cylinders
    assert_equal [], h.blocks
    assert_equal [ 2.4 ], h.liters
    assert_equal %w[KA24E], h.engine_codes
    assert_equal %w[SOHC], h.valvetrains
    assert_equal [ 12 ], h.valves
    assert_equal 1989..2003, h.years
  end

  test "elgin description with mixed engines and trailing note" do
    h = parse("HL7011 CHEVROLET V8 294 4.3 VORTEC 325 5.3 LS1 , 6.0 6.2 VORTEC 16 VAL 99/23 CON RESORTE")

    assert_equal %w[HL7011], h.interchanges
    assert_equal "CHEVROLET", h.make
    assert_equal [ 8 ], h.cylinders
    assert_equal %w[V], h.blocks
    assert_equal [ 294, 325 ], h.cids
    assert_equal [ 4.3, 5.3, 6.0, 6.2 ], h.liters
    assert_equal %w[VORTEC LS1], h.engine_codes
    assert_equal [ 16 ], h.valves
    assert_equal 1999..2023, h.years
    assert_equal [ "CON RESORTE" ], h.notes
  end

  test "rexite description with several layouts" do
    h = parse("DM-152 NISSAN PICKUP L4 L6 1.8 2.4 2.0 KA24DE L20B DOHC SOHC 8V 12V 76/14")

    assert_equal %w[DM-152], h.interchanges
    assert_equal "PICKUP", h.models_text
    assert_equal [ 4, 6 ], h.cylinders
    assert_equal %w[L], h.blocks
    assert_equal [ 1.8, 2.4, 2.0 ], h.liters
    assert_equal %w[KA24DE L20B], h.engine_codes
    assert_equal %w[DOHC SOHC], h.valvetrains
    assert_equal [ 8, 12 ], h.valves
    assert_equal 1976..2014, h.years
  end

  test "safety description" do
    h = parse("83-301 CHEVROLET SILVERADO V6 262 4.3 INC ECOTEC 12 VAL 14/18")

    assert_equal %w[83-301], h.interchanges
    assert_equal "SILVERADO", h.models_text
    assert_equal [ 6 ], h.cylinders
    assert_equal [ 262 ], h.cids
    assert_equal %w[ECOTEC], h.engine_codes
    assert_equal [ 12 ], h.valves
    assert_equal 2014..2018, h.years
  end

  test "revo description with two models" do
    h = parse("9-0511S SA-76260 DDM-77020 CHRYSLER DURANGO JOURNEY V6 3.6 SOHC 24 VAL PENTASTAR 11/13")

    assert_equal %w[9-0511S SA-76260 DDM-77020], h.interchanges
    assert_equal "CHRYSLER", h.make
    assert_equal "DURANGO JOURNEY", h.models_text
    assert_equal [ 3.6 ], h.liters
    assert_equal [ 24 ], h.valves
    assert_equal %w[PENTASTAR], h.engine_codes
    assert_equal 2011..2013, h.years
  end

  test "description without interchanges" do
    h = parse("HONDA RIDGELINE V6 3.5 07/08 197 DIENTES")

    assert_equal [], h.interchanges
    assert_equal "RIDGELINE", h.models_text
    assert_equal 2007..2008, h.years
    assert_equal [ "197 DIENTES" ], h.notes
  end

  test "example description with repeated model and trailing measures" do
    h = parse("QJC-36-1MLO NISSAN NP300 NP300 FRONTIER 4 CIL 2.5 QR25DE DOHC 16 VAL 16/18 DIAMETRO CAB MLS 89MM")

    assert_equal %w[QJC-36-1MLO], h.interchanges
    assert_equal "NP300 NP300 FRONTIER", h.models_text
    assert_equal %w[QR25DE], h.engine_codes
    assert_equal 2016..2018, h.years
    assert_equal [ "DIAMETRO CAB MLS 89MM" ], h.notes
  end

  test "unknown make yields no make and no crash" do
    h = parse("XYZ123 FOO BAR")

    assert_nil h.make
    assert_nil h.years
  end

  test "blank description" do
    h = parse(nil)

    assert_equal [], h.interchanges
    assert_nil h.make
  end
end
