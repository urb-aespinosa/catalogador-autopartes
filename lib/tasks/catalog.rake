namespace :catalog do
  namespace :snapshots do
    desc "Export cached source snapshots to versioned files (default: db/snapshots)"
    task :dump, [ :dir ] => :environment do |_, args|
      dir = args[:dir] || Catalog::SnapshotArchive::DEFAULT_DIR
      Catalog::SnapshotArchive.dump(dir)
      puts "Snapshots exportados: #{SourceSnapshot.count} → #{dir}"
    end

    desc "Load versioned snapshot files into the cache (default: db/snapshots)"
    task :load, [ :dir ] => :environment do |_, args|
      dir = args[:dir] || Catalog::SnapshotArchive::DEFAULT_DIR
      Catalog::SnapshotArchive.load(dir)
      puts "Snapshots en caché: #{SourceSnapshot.count}"
    end
  end
end
