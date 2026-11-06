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
    # The whole block, not just the button: any item update the page missed
    # (sent before it subscribed) is corrected here.
    Turbo::StreamsChannel.broadcast_replace_to run, target: "progress", partial: "runs/progress", locals: { run: run.reload }
  end
end
