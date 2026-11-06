module Catalog
  # Exports snapshots to versioned files (db/snapshots) and loads them back,
  # so a fresh clone reproduces the delivered workbook exactly (D11).
  module SnapshotArchive
    DEFAULT_DIR = Rails.root.join("db/snapshots")

    module_function

    def dump(dir = DEFAULT_DIR)
      FileUtils.mkdir_p(dir)
      SourceSnapshot.order(:url).find_each do |snapshot|
        record = {
          url: snapshot.url, content_type: snapshot.content_type, sha256: snapshot.sha256,
          fetched_at: snapshot.fetched_at.utc.iso8601(6), body_base64: Base64.strict_encode64(snapshot.body)
        }
        File.write(File.join(dir, "#{Digest::SHA256.hexdigest(snapshot.url)}.json"), JSON.pretty_generate(record) + "\n")
      end
    end

    def load(dir = DEFAULT_DIR)
      Dir.glob(File.join(dir, "*.json")).sort.each do |path|
        record = JSON.parse(File.read(path))
        snapshot = SourceSnapshot.find_or_initialize_by(url: record.fetch("url"))
        snapshot.update!(
          body: Base64.strict_decode64(record.fetch("body_base64")),
          content_type: record["content_type"], sha256: record.fetch("sha256"),
          fetched_at: Time.iso8601(record.fetch("fetched_at"))
        )
      end
    end
  end
end
