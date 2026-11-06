module Catalog
  # Runs the whole catalog synchronously (used by `bin/rails catalog:run` and
  # by the double-run test). The web UI runs the same ItemProcessor in jobs.
  module Pipeline
    module_function

    def run(input_path)
      run = File.open(input_path) { |io| Run.create_from_upload!(io, File.basename(input_path)) }
      run.update!(status: "processing")
      run.source_items.each { ItemProcessor.call(_1) }
      run
    end
  end
end
