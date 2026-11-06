module Catalog
  # Builds the "Descripción" of the Catálogo sheet from templates (D4, D13):
  # the product's opening sentence, then one sentence per verified attribute in
  # the product's fixed order. It only mentions what is in the Atributos sheet.
  #
  #   number with unit → "{atributo} de {valor} {unidad}."
  #   anything else    → "{atributo}: {valor en minúsculas}."
  module CatalogDescription
    module_function

    def call(product:, attributes:)
      template = Normalizer::PRODUCTS[product] || {}
      sentences = [ template["opening"], *ordered(attributes, template["attribute_order"].to_a).map { sentence(_1) } ]
      sentences.compact.join(" ")
    end

    def ordered(attributes, order)
      known, rest = attributes.partition { order.include?(_1.name) }
      known.sort_by { order.index(_1.name) } + rest.sort_by(&:name)
    end

    def sentence(attribute)
      if attribute.value.is_a?(Numeric) && attribute.unit.present?
        "#{attribute.name} de #{format_number(attribute.value)} #{attribute.unit}."
      else
        "#{attribute.name}: #{format_number(attribute.value).to_s.downcase}."
      end
    end

    def format_number(value)
      value.is_a?(Float) && value == value.to_i ? value.to_i : value
    end
  end
end
