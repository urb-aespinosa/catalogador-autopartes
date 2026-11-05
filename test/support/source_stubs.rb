# Stubs every official source with the saved responses in
# test/fixtures/files/sources, so the whole pipeline runs without network.
module SourceStubs
  ELGIN = "https://catalog.elginind.com".freeze
  ELGIN_PART = "41add5cf-f231-4fc7-8d33-1ff2b890cb08".freeze
  SAFETY = "https://www.safetyautoparts.com/webcatalog".freeze
  VPIC = "https://vpic.nhtsa.dot.gov/api/vehicles".freeze

  def stub_all_sources_from_fixtures
    stub_elgin
    stub_fraco
    stub_rexite
    stub_safety
    stub_vpic
  end

  def stub_elgin
    stub_source("#{ELGIN}/part-autocomplete/?q=HL-7025S", "elgin/autocomplete_HL-7025S.json", content_type: "application/json")
    stub_source("#{ELGIN}/engine/part/#{ELGIN_PART}/", "elgin/part_HL-7025S.html")
    stub_source("#{ELGIN}/engine/part/#{ELGIN_PART}/?page=2", "elgin/part_HL-7025S_page2.html")
    Dir.children(file_fixture("sources/elgin/engines")).each do |name|
      make, uuid = File.basename(name, ".html").split("_")
      stub_source("#{ELGIN}/engine/#{make}/lifters-tappets/#{uuid}/", "elgin/engines/#{name}")
    end
  end

  def stub_fraco
    %w[FSX-5840301 FSX-5840299].each do |part|
      stub_source("https://www.fraco.com.mx/QRMX/#{part}.pdf", "fraco/#{part}.pdf", content_type: "application/pdf")
    end
  end

  def stub_rexite
    stub_source("https://rexite.net/wp-json/wc/store/v1/products?search=RM-152", "rexite/search_RM-152.json", content_type: "application/json")
  end

  def stub_safety
    stub_request(:get, %r{#{Regexp.escape(SAFETY)}/tradappresults\.php}).to_return(body: "<table></table>")
    %w[GMT GMC].each { stub_source("#{SAFETY}/tradengines.php?MakeCode=#{_1}", "safety/tradengines_#{_1}.html") }
    Dir.children(file_fixture("sources/safety")).grep(/\Atradappresults_/).each do |name|
      stub_source("#{SAFETY}/tradappresults.php?EngineCode=#{name[/tradappresults_(.+)\.html/, 1]}", "safety/#{name}")
    end
  end

  # Model-year lists exist only for the years saved as fixtures; any other
  # year answers with an empty list, so those combinations are not confirmed.
  def stub_vpic
    stub_request(:get, %r{#{Regexp.escape(VPIC)}/GetModelsForMakeYear/}).to_return(
      body: { "Count" => 0, "Results" => [] }.to_json, headers: { "Content-Type" => "application/json" }
    )
    Dir.children(file_fixture("sources/vpic")).each do |name|
      if (match = name.match(/\Amodels_(\w+)_(\d{4})\.json\z/))
        make = match[1] == "gmc" ? "GMC" : match[1].capitalize
        stub_source("#{VPIC}/GetModelsForMakeYear/make/#{make}/modelyear/#{match[2]}?format=json", "vpic/#{name}", content_type: "application/json")
      elsif (match = name.match(/\Amodels_(\w+)\.json\z/))
        make = match[1] == "gmc" ? "GMC" : match[1].capitalize
        stub_source("#{VPIC}/GetModelsForMake/#{make}?format=json", "vpic/#{name}", content_type: "application/json")
      end
    end
  end
end
