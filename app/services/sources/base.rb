module Sources
  # Common helpers for the official-source adapters.
  class Base
    ORIGIN = "oficial".freeze

    # call(item:, hints:) -> Sources::Result
    def call(item:, hints:) = raise NotImplementedError

    private

    def fetch_html(url) = Nokogiri::HTML(Catalog::Fetcher.get(url).body)

    def application(**values)
      Catalog::Records::Application.new(
        **Catalog::Records::Application.members.index_with(nil),
        origin: ORIGIN, evidence_urls: [], **values
      )
    end

    def attribute(name:, value:, url:, unit: nil, original: nil, origin: ORIGIN)
      Catalog::Records::Attribute.new(
        klass: nil, name: name, unit: unit, value: value, url: url, origin: origin,
        original: original || [ value, unit ].compact.join(" ")
      )
    end
  end
end
