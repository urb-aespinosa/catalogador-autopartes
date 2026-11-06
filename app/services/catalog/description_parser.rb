module Catalog
  # Turns the free-text ERP description into search hints. Deterministic
  # rules only (D1: hints search and validate, they never become rows).
  #
  # Layout: [interchanges] MAKE [models] [engine tokens] AA/AA [notes]
  class DescriptionParser
    VOCABULARY = YAML.load_file(Rails.root.join("config/catalog/parser.yml")).freeze
    MAKES = VOCABULARY.fetch("makes").to_set.freeze
    NOTE_WORDS = VOCABULARY.fetch("note_words").to_set.freeze
    YEAR_RANGE = %r{\A(\d{2})/(\d{2})\z}
    YEAR_PIVOT = 30 # fixed, never the current date: AA < 30 → 20AA

    def self.call(text) = new(text).hints

    def self.expand_year(two_digits)
      value = two_digits.to_i
      value < YEAR_PIVOT ? 2000 + value : 1900 + value
    end

    def initialize(text)
      @tokens = text.to_s.upcase.split
    end

    def hints
      make_at = @tokens.index { MAKES.include?(_1) }
      years_at = @tokens.index { YEAR_RANGE.match?(_1) }
      body_end = years_at || @tokens.size
      engine_at = (make_at ? make_at + 1 : 0).upto(body_end - 1).find { engine_token?(_1) } || body_end

      @hints = empty_hints
      @hints[:interchanges] = make_at ? @tokens[0...make_at] : []
      @hints[:make] = make_at && @tokens[make_at]
      @hints[:models_text] = make_at ? @tokens[(make_at + 1)...engine_at].join(" ") : ""
      read_engine(engine_at...body_end)
      read_years_and_notes(years_at)

      Hints.new(**@hints.transform_values { _1.is_a?(Array) ? _1.uniq : _1 })
    end

    private

    def empty_hints
      {
        interchanges: [], make: nil, models_text: "", cylinders: [], blocks: [], liters: [],
        cids: [], engine_codes: [], valvetrains: [], valves: [], years: nil, notes: []
      }
    end

    def engine_token?(index)
      token = @tokens[index]
      following = @tokens[index + 1]
      return true if token.match?(/\A\d+\z/) && %w[CIL VAL].include?(following)

      token.match?(/\A[LV]\d{1,2}\z|\A\d\.\d\z|\A\d{3}\z|\A\d{1,2}V\z|\A[SD]OHC\z/)
    end

    def read_engine(range)
      skip_next = false
      range.each do |index|
        if skip_next
          skip_next = false
          next
        end
        skip_next = read_engine_token(@tokens[index], @tokens[index + 1])
      end
    end

    # Returns true when the token consumed the following one ("4 CIL", "12 VAL").
    def read_engine_token(token, following)
      return read_number(token, following) if token.match?(/\A\d+\z/)

      case token
      when /\A([LV])(\d{1,2})\z/
        @hints[:blocks] << $1
        @hints[:cylinders] << $2.to_i
      when /\A\d\.\d\z/ then @hints[:liters] << token.to_f
      when /\A(\d{1,2})V\z/ then @hints[:valves] << $1.to_i
      when /\A[SD]OHC\z/ then @hints[:valvetrains] << token
      when /[A-Z]/
        @hints[NOTE_WORDS.include?(token) ? :notes : :engine_codes] << token
      end
      false
    end

    def read_number(token, following)
      case following
      when "CIL" then @hints[:cylinders] << token.to_i
      when "VAL" then @hints[:valves] << token.to_i
      else
        @hints[:cids] << token.to_i if token.length == 3
        return false
      end
      true
    end

    def read_years_and_notes(years_at)
      return unless years_at

      from, to = YEAR_RANGE.match(@tokens[years_at]).captures
      @hints[:years] = self.class.expand_year(from)..self.class.expand_year(to)
      trailing = @tokens[(years_at + 1)..].join(" ")
      @hints[:notes] << trailing if trailing.present?
    end
  end
end
