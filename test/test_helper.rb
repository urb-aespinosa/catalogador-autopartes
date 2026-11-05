ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
Dir[File.expand_path("support/**/*.rb", __dir__)].each { require _1 }

# Tests never touch the network: every source response comes from a fixture.
WebMock.disable_net_connect!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SourceStubs
    include WorkbookReader

    # Stubs a GET to `url` with a saved source response (a path under
    # test/fixtures/files/sources), inline JSON or an inline body.
    def stub_source(url, fixture = nil, json: nil, body: nil, status: 200, content_type: nil)
      body = file_fixture("sources/#{fixture}").binread if fixture
      if json
        body = json.to_json
        content_type ||= "application/json"
      end
      stub_request(:get, url).to_return(
        status: status, body: body.to_s, headers: { "Content-Type" => content_type || "text/html" }
      )
    end

    def with_env(vars)
      previous = vars.keys.to_h { [ _1, ENV[_1] ] }
      vars.each { ENV[_1] = _2 }
      yield
    ensure
      previous.each { ENV[_1] = _2 }
    end
  end
end
