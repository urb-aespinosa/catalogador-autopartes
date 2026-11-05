require "test_helper"

class Catalog::CatalogDescriptionTest < ActiveSupport::TestCase
  def attr(name, value, unit = nil)
    Catalog::Records::Attribute.new(klass: name, name: name, unit: unit, value: value, url: "u", origin: "oficial", original: value.to_s)
  end

  def describe(product, attributes) = Catalog::CatalogDescription.call(product: product, attributes: attributes)

  test "opening plus attribute sentences in the product's fixed order" do
    text = describe("JUEGO DE PUNTERÍAS DE MOTOR", [ attr("Longitud", 98.55, "mm"), attr("Material", "Acero"), attr("Tipo de puntería", "Hidráulica") ])

    assert_equal "Juego de punterías de motor para transmitir el movimiento del árbol de levas a las válvulas. " \
                 "Tipo de puntería: hidráulica. Material: acero. Longitud de 98.55 mm.", text
  end

  test "text attribute uses the colon template with a lowercase value" do
    text = describe("BOMBA DE ACEITE DEL MOTOR", [ attr("Material de la carcasa", "Hierro fundido") ])

    assert_equal "Bomba de aceite del motor para impulsar y distribuir el aceite del motor. Material de la carcasa: hierro fundido.", text
  end

  test "a number without unit uses the colon template and no trailing .0" do
    text = describe("JUEGO DE EMPAQUES DE MOTOR", [ attr("Número de válvulas", 16), attr("Diámetro", 89.0, "mm"), attr("Junta Cabeza", "MLS") ])

    assert_equal "Juego de empaques de motor para sellar las uniones del motor. Número de válvulas: 16. Diámetro de 89 mm. Junta Cabeza: mls.", text
  end

  test "attributes outside the fixed order go last, alphabetically" do
    text = describe("PISTÓN DE MOTOR", [ attr("Zeta", "b"), attr("Alfa", "a"), attr("Sobremedida", "0.50 mm (+0.020\")") ])

    assert_equal "El Pistón de motor forma parte del conjunto móvil del motor. Sobremedida: 0.50 mm (+0.020\"). Alfa: a. Zeta: b.", text
  end

  test "no attributes gives only the opening" do
    assert_equal "Bomba de aceite del motor para impulsar y distribuir el aceite del motor.", describe("BOMBA DE ACEITE DEL MOTOR", [])
  end

  test "a product without template gives only the attribute sentences" do
    assert_equal "Material: acero.", describe("PUNTERIAS", [ attr("Material", "Acero") ])
  end
end
