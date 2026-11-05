module Sources
  # What every adapter returns. Values are as the source publishes them:
  # adapters never translate or normalize (Catalog::Normalizer does).
  Result = Data.define(
    :status, :product_kind, :applications, :interchanges, :attributes,
    :per_engine_years, :market, :validations
  ) do
    def self.not_found(market:) = found(market: market).with(status: :not_found)

    def self.found(market:, product_kind: nil, applications: [], interchanges: [], attributes: [], per_engine_years: false, validations: [])
      new(
        status: :found, product_kind: product_kind, applications: applications, interchanges: interchanges,
        attributes: attributes, per_engine_years: per_engine_years, market: market, validations: validations
      )
    end
  end
end
