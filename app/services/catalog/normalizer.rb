module Catalog
  # Turns what an adapter found (source language and units) into catalog rows
  # (Spanish, mm) using only the versioned dictionaries in config/catalog (D7).
  # A term missing from a dictionary keeps its original text and is reported
  # as "sin traducción"; nothing is guessed.
  class Normalizer
    def self.dictionary(name) = YAML.load_file(Rails.root.join("config/catalog/#{name}.yml")).freeze

    PRODUCT_CONFIG = dictionary("products")
    PRODUCTS = PRODUCT_CONFIG.fetch("products").freeze
    PRODUCT_RULES = PRODUCT_CONFIG.fetch("rules").freeze
    BRANDS = dictionary("brands")
    ATTRIBUTES = dictionary("attributes")
    VALUES = dictionary("values")
    FUELS = dictionary("fuels")
    OVERSIZES = dictionary("oversizes")
    MAKES_CONFIG = dictionary("makes")
    OEM_BRANDS = MAKES_CONFIG.fetch("oem_brands").map(&:upcase).to_set.freeze
    NUMBER = /\A-?\d+(\.\d+)?\z/

    def self.call(item:, result:) = new(item, result).call

    def self.inches_to_mm(value) = (value.to_f * 25.4).round(2)

    def self.brand_for(manufacturer) = BRANDS.fetch(manufacturer.to_s.strip.upcase, manufacturer.to_s.strip)

    def self.product_for(item_group:, product_kind:)
      group = item_group.to_s.strip.upcase
      rule = PRODUCT_RULES.find { _1["group"] == group && (_1["kind"].nil? || _1["kind"] == product_kind.to_s) }
      rule && rule["product"]
    end

    def initialize(item, result)
      @item = item
      @result = result&.status == :found ? result : nil
      @validations = []
    end

    def call
      Records::ItemResult.new(
        product: product,
        applications: Array(@result&.applications).map { normalize_application(_1) },
        interchanges: Array(@result&.interchanges).map { normalize_interchange(_1) },
        attributes: Array(@result&.attributes).map { normalize_attribute(_1) },
        validations: Array(@result&.validations) + @validations.uniq
      )
    end

    private

    def product
      self.class.product_for(item_group: @item.item_group, product_kind: @result&.product_kind) || begin
        @validations << Records::Validation.new(field: "Producto", erp_value: @item.item_group, source_value: nil, url: nil, status: "sin traducción")
        @item.item_group
      end
    end

    def normalize_application(app)
      app.with(manufacturer: make(app), fuel: fuel(app))
    end

    def make(app)
      MAKES_CONFIG.fetch("display").fetch(app.manufacturer.to_s.upcase) do
        untranslated(app.manufacturer, app.url)
        app.manufacturer
      end
    end

    def fuel(app)
      return nil if app.fuel.nil?

      FUELS.fetch(app.fuel) { untranslated(app.fuel, app.url) && app.fuel }
    end

    def normalize_interchange(interchange)
      interchange.with(kind: OEM_BRANDS.include?(interchange.brand.to_s.upcase) ? "OEM" : "Aftermarket")
    end

    def normalize_attribute(attribute)
      names = ATTRIBUTES[attribute.name]
      untranslated(attribute.name, attribute.url) unless names
      return oversize(attribute, names) if attribute.name == "Sobremedida"

      value, unit = measure(attribute)
      attribute.with(klass: names&.fetch("klass") || attribute.name, name: names&.fetch("name") || attribute.name, value: value, unit: unit)
    end

    def measure(attribute)
      raw = attribute.value.to_s.strip
      return [ category(raw, attribute.url), attribute.unit ] unless raw.match?(NUMBER)

      case attribute.unit.to_s.upcase
      when "IN" then [ self.class.inches_to_mm(raw), "mm" ]
      when "", "MM" then [ number(raw), attribute.unit&.downcase ]
      else
        untranslated(attribute.unit, attribute.url)
        [ number(raw), attribute.unit ]
      end
    end

    def category(raw, url)
      VALUES.fetch(raw) { untranslated(raw, url) && raw }
    end

    def oversize(attribute, names)
      value = OVERSIZES.fetch(attribute.value.to_s) { untranslated(attribute.value, attribute.url) && attribute.value }
      attribute.with(klass: names&.fetch("klass") || "Sobremedida", name: names&.fetch("name") || "Sobremedida", value: value, unit: nil)
    end

    def number(raw)
      value = raw.to_f
      value == value.to_i ? value.to_i : value
    end

    def untranslated(term, url)
      @validations << Records::Validation.new(field: "Traducción", erp_value: nil, source_value: term.to_s, url: url, status: "sin traducción")
    end
  end
end
