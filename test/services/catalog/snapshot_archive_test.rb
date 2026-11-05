require "test_helper"

class Catalog::SnapshotArchiveTest < ActiveSupport::TestCase
  test "dump then load restores identical snapshots, including binary bodies" do
    pdf = "%PDF-1.7\x00\xFF binary".b
    SourceSnapshot.create!(url: "https://example.com/a.pdf", body: pdf, content_type: "application/pdf", sha256: Digest::SHA256.hexdigest(pdf), fetched_at: Time.utc(2026, 11, 5, 12))
    SourceSnapshot.create!(url: "https://example.com/b", body: "hola", content_type: "text/html", sha256: Digest::SHA256.hexdigest("hola"), fetched_at: Time.utc(2026, 11, 5, 13))
    before = SourceSnapshot.order(:url).map { [ _1.url, _1.body.b, _1.sha256, _1.content_type, _1.fetched_at ] }

    Dir.mktmpdir do |dir|
      Catalog::SnapshotArchive.dump(dir)
      assert_equal 2, Dir.children(dir).size
      SourceSnapshot.delete_all

      Catalog::SnapshotArchive.load(dir)
    end

    assert_equal before, SourceSnapshot.order(:url).map { [ _1.url, _1.body.b, _1.sha256, _1.content_type, _1.fetched_at ] }
  end

  test "load is idempotent" do
    SourceSnapshot.create!(url: "https://example.com/b", body: "hola", content_type: "text/html", sha256: "s", fetched_at: Time.utc(2026, 11, 5))

    Dir.mktmpdir do |dir|
      Catalog::SnapshotArchive.dump(dir)
      2.times { Catalog::SnapshotArchive.load(dir) }
    end

    assert_equal 1, SourceSnapshot.count
  end

  test "load of a missing directory does nothing" do
    assert_nothing_raised { Catalog::SnapshotArchive.load("/nonexistent/snapshots") }
  end
end
