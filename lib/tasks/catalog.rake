namespace :catalog do
  desc "Build the catalog workbook from an ERP Excel: catalog:run[input.xlsx,output.xlsx]"
  task :run, [ :input, :output ] => :environment do |_, args|
    input = args[:input] || abort("Uso: bin/rails 'catalog:run[entrada.xlsx,salida.xlsx]'")
    output = args[:output] || Rails.root.join("tmp/catalogo.xlsx").to_s

    run = Catalog::Pipeline.run(input)
    Catalog::WorkbookExporter.call(run, output)
    run.update!(status: "done")
    summary = run.source_items.map { "#{_1.part_number}: #{_1.status}" }.join(", ")
    puts "Catálogo generado: #{output} (#{summary})"
  end

  namespace :inegi do
    desc "Rebuild the Nissan/GM extract of INEGI RAIAVL sales from the versioned zip (D19)"
    task filter: :environment do
      rows = Catalog::InegiSalesFilter.call
      puts "Extracto INEGI: #{rows} filas → #{Catalog::InegiSalesFilter::OUTPUT.relative_path_from(Rails.root)}"
    end
  end

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
