module Catalog
  # Search hints extracted from the ERP description by DescriptionParser.
  Hints = Data.define(
    :interchanges, :make, :models_text, :cylinders, :blocks, :liters, :cids,
    :engine_codes, :valvetrains, :valves, :years, :notes
  )
end
