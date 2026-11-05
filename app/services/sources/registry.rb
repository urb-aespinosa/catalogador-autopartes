module Sources
  # Maps the ERP "Fabricante" column to the adapter of its official source.
  # A manufacturer without an entry has no official source (e.g. REVO).
  module Registry
    ADAPTERS = {
      "ELGIN" => "Sources::Elgin"
    }.freeze

    def self.for(manufacturer)
      name = ADAPTERS[manufacturer.to_s.strip.upcase]
      name&.constantize&.new
    end
  end
end
