module Catalog
  # Value objects shared by the whole pipeline. They are stored as JSON in
  # SourceItem#result (D12), so each one knows how to go to and from a Hash.
  module Records
    module Serializable
      def self.included(base) = base.extend(ClassMethods)

      module ClassMethods
        def from_h(hash)
          hash = hash.transform_keys(&:to_sym)
          new(**members.to_h { |key| [ key, hash[key] ] })
        end
      end
    end

    # vpic_unknown (D20): set by Vpic.expand when vPIC lists the model name in
    # no year at all; MarketResolver consumes it and clears it.
    Application = Data.define(
      :manufacturer, :model, :submodel, :year, :years, :liters, :cc, :cid, :cylinders,
      :block, :fuel, :market, :url, :origin, :original, :evidence_urls, :vpic_unknown
    ) do
      include Serializable

      # Ranges do not survive JSON, so years travel as [first, last].
      def to_h = super.merge(years: years && [ years.first, years.last ])

      def self.from_h(hash)
        app = super
        pair = app.years
        pair.is_a?(Array) ? app.with(years: pair.first..pair.last) : app
      end
    end

    Interchange = Data.define(:number, :brand, :kind, :url, :origin) do
      include Serializable
    end

    Attribute = Data.define(:klass, :name, :unit, :value, :url, :origin, :original) do
      include Serializable
    end

    Validation = Data.define(:field, :erp_value, :source_value, :url, :status) do
      include Serializable
    end

    ItemResult = Data.define(:product, :applications, :interchanges, :attributes, :validations) do
      def to_h
        {
          product: product,
          applications: applications.map(&:to_h),
          interchanges: interchanges.map(&:to_h),
          attributes: attributes.map(&:to_h),
          validations: validations.map(&:to_h)
        }
      end

      def self.from_h(hash)
        hash = hash.transform_keys(&:to_sym)
        new(
          product: hash[:product],
          applications: Array(hash[:applications]).map { Application.from_h(_1) },
          interchanges: Array(hash[:interchanges]).map { Interchange.from_h(_1) },
          attributes: Array(hash[:attributes]).map { Attribute.from_h(_1) },
          validations: Array(hash[:validations]).map { Validation.from_h(_1) }
        )
      end
    end
  end
end
