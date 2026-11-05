require "test_helper"

class Catalog::FetcherTest < ActiveSupport::TestCase
  test "downloads once and serves from cache" do
    stub = stub_request(:get, "https://example.com/a").to_return(body: "hi")

    2.times { Catalog::Fetcher.get("https://example.com/a") }

    assert_requested stub, times: 1
    assert_equal "hi", SourceSnapshot.find_by!(url: "https://example.com/a").body
  end

  test "FORCE_REFRESH downloads again and replaces the snapshot" do
    stub_request(:get, "https://example.com/a").to_return({ body: "old" }, { body: "new" })
    Catalog::Fetcher.get("https://example.com/a")

    with_env("FORCE_REFRESH" => "1") { Catalog::Fetcher.get("https://example.com/a") }

    assert_equal "new", SourceSnapshot.find_by!(url: "https://example.com/a").body
    assert_equal 1, SourceSnapshot.count
  end

  test "stores content type and sha256" do
    stub_request(:get, "https://example.com/a").to_return(body: "hi", headers: { "Content-Type" => "text/html; charset=utf-8" })

    snapshot = Catalog::Fetcher.get("https://example.com/a")

    assert_equal "text/html; charset=utf-8", snapshot.content_type
    assert_equal Digest::SHA256.hexdigest("hi"), snapshot.sha256
  end

  test "sends the project user agent" do
    stub = stub_request(:get, "https://example.com/a")
      .with(headers: { "User-Agent" => "catalogador-autopartes/1.0 (prueba tecnica)" })

    Catalog::Fetcher.get("https://example.com/a")

    assert_requested stub
  end

  test "uses a 15 second timeout" do
    assert_equal 15, Rails.configuration.x.catalog.timeout
  end

  test "timeout raises SourceError and caches nothing" do
    stub_request(:get, "https://example.com/slow").to_timeout

    error = assert_raises(Catalog::Fetcher::SourceError) { Catalog::Fetcher.get("https://example.com/slow") }

    assert_match "timeout", error.detail
    assert_equal "https://example.com/slow", error.url
    assert_equal 0, SourceSnapshot.count
  end

  test "non-200 raises SourceError with the status" do
    stub_request(:get, "https://example.com/x").to_return(status: 403)

    error = assert_raises(Catalog::Fetcher::SourceError) { Catalog::Fetcher.get("https://example.com/x") }

    assert_equal 403, error.status
    assert_match "403", error.detail
    assert_equal 0, SourceSnapshot.count
  end

  test "get_json parses the body" do
    stub_source("https://example.com/j", json: [ { "label" => "HL-7025S" } ])

    assert_equal [ { "label" => "HL-7025S" } ], Catalog::Fetcher.get_json("https://example.com/j")
  end

  test "get_json on a non-JSON body raises SourceError" do
    stub_source("https://example.com/j", body: "<html>maintenance</html>")

    assert_raises(Catalog::Fetcher::SourceError) { Catalog::Fetcher.get_json("https://example.com/j") }
  end

  test "encodes slash and plus in path segments" do
    assert_equal "SP26-329R%2FL%2B20", Catalog::Fetcher.encode_path("SP26-329R/L+20")
    assert_equal "Land%20Rover", Catalog::Fetcher.encode_path("Land Rover")
  end

  test "a concurrent insert of the same url reuses the stored snapshot" do
    # Another job stores the URL while this request is in flight.
    stub_request(:get, "https://example.com/a").to_return do
      SourceSnapshot.create!(url: "https://example.com/a", body: "first", sha256: "s", content_type: "text/html", fetched_at: Time.utc(2026, 11, 5))
      { body: "second" }
    end

    assert_equal "first", Catalog::Fetcher.get("https://example.com/a").body
    assert_equal 1, SourceSnapshot.count
  end
end
