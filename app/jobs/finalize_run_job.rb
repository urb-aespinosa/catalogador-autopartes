class FinalizeRunJob < ApplicationJob
  queue_as :default

  FILENAME = "catalogo_bonaparte.xlsx".freeze

  def perform(run)
    Tempfile.create([ "catalogo", ".xlsx" ]) do |file|
      Catalog::WorkbookExporter.call(run, file.path)
      run.output.attach(io: File.open(file.path), filename: FILENAME,
                        content_type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    end
    run.update!(status: "done")
    Turbo::StreamsChannel.broadcast_replace_to run, target: "download", partial: "runs/download", locals: { run: run }
  end
end
