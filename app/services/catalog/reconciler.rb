module Catalog
  # Compares each hint from the ERP description against what the official
  # source says (spec §6.4) and writes one Validación row per hint value.
  # It never changes catalog data: discrepancies are only reported.
  #
  #   coincide       the source has the field and the value matches
  #   difiere        the source has the field and the value does not match
  #   no encontrado  the source does not publish that field
  class Reconciler
    SET_UNITS = %w[JUEGO KIT].freeze
    # Presentation stated by the source itself (Sources::Result#product_kind).
    KIND_LABELS = { set: "juego", chain: "kit" }.freeze

    def self.call(item:, hints:, result:, product_kind: nil) = new(item, hints, result, product_kind).validations

    def initialize(item, hints, result, product_kind)
      @item = item
      @hints = hints
      @product_kind = product_kind
      @apps = result.applications
      @interchanges = result.interchanges
      @attributes = result.attributes
      @product = result.product
      @has_source = [ @apps, @interchanges, @attributes ].any?(&:present?)
      @url = @apps.first&.url || @attributes.first&.url
    end

    def validations
      [
        make_row, model_row,
        *values_rows("Litros", @hints.liters, @apps.map(&:liters)),
        *values_rows("Cilindros", @hints.cylinders, @apps.map(&:cylinders)),
        *values_rows("CID", @hints.cids, @apps.map(&:cid)),
        *values_rows("Válvulas", @hints.valves, @attributes.select { _1.name == "Número de válvulas" }.map(&:value)),
        *values_rows("Árbol de levas", @hints.valvetrains, []),
        *values_rows("Código de motor", @hints.engine_codes, []),
        years_row, *interchange_rows, unit_row
      ].compact
    end

    private

    def make_row
      return unless @hints.make

      sources = @apps.map(&:manufacturer).compact.uniq
      row("Armadora", @hints.make, sources, sources.any? { _1.casecmp?(@hints.make) })
    end

    # "PICK UP" matches "Pickup": names are compared without case, spaces or symbols.
    def model_row
      return if @hints.models_text.blank?

      erp = squash(@hints.models_text)
      sources = @apps.map(&:model).compact.uniq
      row("Modelo", @hints.models_text, sources, sources.any? { erp.include?(squash(_1)) || squash(_1).include?(erp) })
    end

    def values_rows(field, hint_values, source_values)
      sources = source_values.compact.uniq
      hint_values.map { |value| row(field, format_value(value), sources.map { format_value(_1) }, sources.any? { same_number?(_1, value) }) }
    end

    def years_row
      return unless @hints.years

      years = @apps.map(&:year).compact
      source = years.any? ? "#{years.min}-#{years.max}" : nil
      status = if years.empty? then "no encontrado"
      elsif years.any? { @hints.years.cover?(_1) } then "coincide"
      else "difiere"
      end
      validation("Años", "#{@hints.years.first}-#{@hints.years.last}", source, status)
    end

    # D9: an ERP interchange is confirmed only by a source; otherwise not found.
    def interchange_rows
      numbers = @interchanges.map { squash(_1.number) }
      @hints.interchanges.map do |number|
        validation("Intercambio", number, nil, numbers.include?(squash(number)) ? "coincide" : "no encontrado")
      end
    end

    # Only a presentation the source states (e.g. Elgin "Package of 4") is
    # compared; the product name comes from the ERP group and proves nothing.
    def unit_row
      return if @item.unit.blank?

      label = KIND_LABELS[@product_kind]
      return validation("Unidad", @item.unit, nil, "no encontrado") unless label

      erp_set = SET_UNITS.include?(@item.unit.upcase)
      validation("Unidad", @item.unit, label, erp_set ? "coincide" : "difiere")
    end

    def row(field, erp_value, source_values, match)
      status = if source_values.empty? then "no encontrado"
      elsif match then "coincide"
      else "difiere"
      end
      validation(field, erp_value, source_values.presence&.join(", "), status)
    end

    def validation(field, erp_value, source_value, status)
      Records::Validation.new(field: field, erp_value: erp_value, source_value: source_value, url: @url, status: status)
    end

    def same_number?(a, b) = a.to_f == b.to_f

    def format_value(value)
      value.is_a?(Float) && value == value.to_i ? value.to_i.to_s : value.to_s
    end

    def squash(text) = text.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end
end
