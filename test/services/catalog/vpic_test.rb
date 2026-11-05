require "test_helper"

class Catalog::VpicTest < ActiveSupport::TestCase
  VPIC = "https://vpic.nhtsa.dot.gov/api/vehicles".freeze

  setup do
    [ 2007, 2020 ].each do |year|
      stub_source("#{VPIC}/GetModelsForMakeYear/make/Chevrolet/modelyear/#{year}?format=json", "vpic/models_chevrolet_#{year}.json", content_type: "application/json")
    end
    stub_source("#{VPIC}/GetModelsForMake/Chevrolet?format=json", "vpic/models_chevrolet.json", content_type: "application/json")
    stub_source("#{VPIC}/GetModelsForMake/GMC?format=json", "vpic/models_gmc.json", content_type: "application/json")
  end

  def application(**values)
    Catalog::Records::Application.new(
      **Catalog::Records::Application.members.index_with(nil),
      manufacturer: "CHEVROLET", market: "USA", url: "https://elgin/engine", origin: "oficial", evidence_urls: [], **values
    )
  end

  test "keeps only the model-years vPIC confirms" do
    rows, validations = Catalog::Vpic.expand([ application(model: "Avalanche", years: 2007..2007) ])

    assert_equal [ 2007 ], rows.map(&:year)
    assert_nil rows.first.years
    assert_equal [ [ "verificación NHTSA vPIC", "#{VPIC}/GetModelsForMakeYear/make/Chevrolet/modelyear/2007?format=json" ] ], rows.first.evidence_urls
    assert_empty validations
  end

  test "a discontinued model-year goes to validation instead of a row" do
    rows, validations = Catalog::Vpic.expand([ application(model: "Avalanche", years: 2020..2020) ])

    assert_empty rows
    assert_equal 1, validations.size
    assert_equal [ "Modelo-año", "Chevrolet Avalanche 2020", "no encontrado" ], [ validations.first.field, validations.first.source_value, validations.first.status ]
  end

  test "the vPIC model may be the leading words of the source model" do
    rows, = Catalog::Vpic.expand([ application(model: "Silverado 1500 HD Classic", years: 2007..2007) ])

    assert_equal [ 2007 ], rows.map(&:year)
  end

  test "partial words do not match" do
    rows, validations = Catalog::Vpic.expand([ application(model: "Expressway", years: 2007..2007) ])

    assert_empty rows
    assert_equal 1, validations.size
  end

  test "unconfirmed years of one application are reported together as ranges" do
    (2008..2019).each do |year|
      stub_source("#{VPIC}/GetModelsForMakeYear/make/Chevrolet/modelyear/#{year}?format=json", "vpic/models_chevrolet_2020.json", content_type: "application/json")
    end

    rows, validations = Catalog::Vpic.expand([ application(model: "Avalanche", years: 2007..2020) ])

    assert_equal [ 2007 ], rows.map(&:year)
    assert_equal 1, validations.size
    assert_equal "Chevrolet Avalanche 2008-2020", validations.first.source_value
  end

  test "rows with a single year or from MEX sources are untouched" do
    mex = application(model: "280ZX", year: 1981, market: "MEX")
    single = application(model: "Silverado", year: 2014)

    assert_equal [ [ mex, single ], [] ], Catalog::Vpic.expand([ mex, single ])
  end

  test "identifies the make that owns a model" do
    assert_equal "Chevrolet", Catalog::Vpic.identify_make("Silverado", candidates: %w[Chevrolet GMC]).first
    assert_equal "GMC", Catalog::Vpic.identify_make("Sierra", candidates: %w[Chevrolet GMC]).first
    assert_equal "#{VPIC}/GetModelsForMake/GMC?format=json", Catalog::Vpic.identify_make("Savana", candidates: %w[Chevrolet GMC]).last
  end

  test "a model in no candidate make is not identified" do
    assert_equal [ nil, nil ], Catalog::Vpic.identify_make("Nonexistent", candidates: %w[Chevrolet GMC])
  end

  test "a model in several candidate makes is not guessed" do
    stub_source("#{VPIC}/GetModelsForMake/Twin?format=json", "vpic/models_chevrolet.json", content_type: "application/json")

    assert_equal [ nil, nil ], Catalog::Vpic.identify_make("Silverado", candidates: %w[Chevrolet Twin])
  end
end
