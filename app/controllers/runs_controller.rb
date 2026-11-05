class RunsController < ApplicationController
  def new
  end

  # Reads the upload, creates one item per source row and processes each item
  # in its own job; the run page then follows them live (Turbo Streams).
  def create
    upload = params.dig(:run, :input)
    return render_error("Selecciona un archivo Excel (.xlsx).") unless upload.respond_to?(:path)

    run = Run.create_from_upload!(upload, upload.original_filename)
    run.update!(status: "processing")
    run.source_items.each { ProcessItemJob.perform_later(_1) }
    redirect_to run
  rescue Catalog::SourceWorkbook::InvalidFile => e
    render_error(e.message)
  end

  def show
    @run = Run.find(params[:id])
  end

  private

  def render_error(message)
    @error = message
    render :new, status: :unprocessable_entity
  end
end
