require "test_helper"

class Catalog::EpaVehiclesFilterTest < ActiveSupport::TestCase
  # Shaped like EPA's vehicles.csv: many more columns, ours not first.
  HEADER = %w[barrels08 cylinders displ drive fuelType id make model year atvType trany].freeze

  setup do
    @dir = Rails.root.join("tmp/epa_filter_test_#{Process.pid}")
    FileUtils.mkdir_p(@dir)
    @output = @dir.join("scope.csv")
  end

  teardown { FileUtils.rm_rf(@dir) }

  def vehicle(year, make, model, id, displ, cylinders, fuel, atv = "")
    { "barrels08" => "17.3", "cylinders" => cylinders, "displ" => displ, "drive" => "4-Wheel Drive",
      "fuelType" => fuel, "id" => id, "make" => make, "model" => model, "year" => year,
      "atvType" => atv, "trany" => "Automatic 6-spd" }
  end

  def build_zip(vehicles, header: HEADER)
    path = @dir.join("vehicles.csv.zip")
    Zip::OutputStream.open(path.to_s) do |zip|
      zip.put_next_entry("vehicles.csv")
      zip.write(CSV.generate { |csv| csv << header; vehicles.each { |v| csv << header.map { v[_1] } } })
    end
    path
  end

  def filter(zip) = Catalog::EpaVehiclesFilter.call(zip, @output)

  test "keeps the makes in scope, only the used columns, sorted totally" do
    zip = build_zip([
      vehicle(2016, "Toyota", "Tacoma 4WD", 36000, "3.5", "6", "Regular"),
      vehicle(2016, "Chevrolet", "Silverado C15 2WD", 36500, "5.3", "8", "Regular", "FFV"),
      vehicle(2005, "Buick", "Lacrosse/Allure", 20100, "3.8", "6", "Regular"),
      vehicle(2016, "Chevrolet", "Silverado C15 2WD", 36400, "4.3", "6", "Regular"),
      vehicle(2005, "Buick", "Lacrosse/Allure", 20099, "3.6", "6", "Premium")
    ])

    assert_equal 4, filter(zip)

    assert_equal <<~CSV, File.read(@output)
      year,make,model,id,displ,cylinders,fuelType,atvType
      2005,Buick,Lacrosse/Allure,20099,3.6,6,Premium,
      2005,Buick,Lacrosse/Allure,20100,3.8,6,Regular,
      2016,Chevrolet,Silverado C15 2WD,36400,4.3,6,Regular,
      2016,Chevrolet,Silverado C15 2WD,36500,5.3,8,Regular,FFV
    CSV
  end

  test "two runs produce identical bytes" do
    zip = build_zip([ vehicle(2010, "Nissan", "Frontier 4WD", 29000, "4.0", "6", "Regular"),
                      vehicle(2010, "Nissan", "Frontier 2WD", 28999, "2.5", "4", "Regular") ])

    filter(zip)
    first = File.binread(@output)
    filter(zip)

    assert_equal first, File.binread(@output)
  end

  test "a missing column fails loudly" do
    zip = build_zip([ vehicle(2010, "Nissan", "Frontier 4WD", 29000, "4.0", "6", "Regular") ], header: HEADER - [ "atvType" ])

    error = assert_raises(Catalog::EpaVehiclesFilter::FormatError) { filter(zip) }
    assert_match "atvType", error.message
    assert_not File.exist?(@output)
  end

  test "the committed extract is exactly what the committed zip produces" do
    Catalog::EpaVehiclesFilter.call(Catalog::EpaVehiclesFilter::SOURCE, @output)

    assert_equal Digest::SHA256.file(Catalog::EpaVehiclesFilter::OUTPUT).hexdigest, Digest::SHA256.file(@output).hexdigest
  end
end
