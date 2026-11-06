require "test_helper"

class RunsControllerTest < ActionDispatch::IntegrationTest
  test "the home page shows the upload form" do
    get root_path

    assert_response :success
    assert_select "form input[type=file][name='run[input]']"
  end

  test "upload creates a run and enqueues one job per item" do
    assert_enqueued_jobs 5, only: ProcessItemJob do
      post runs_path, params: { run: { input: fixture_file_upload("data_prueba_tecnica.xlsx") } }
    end

    run = Run.last
    assert_equal "processing", run.status
    assert_redirected_to run_path(run)
    follow_redirect!
    assert_select "[id^=source_item_]", 5
    assert_select "#source_item_#{run.source_items.first.id}", /pendiente/
  end

  # Manual verification finding: Turbo submits the form accepting turbo
  # streams first and follows the redirect with the same Accept header. The
  # run page must still come back as the full HTML page, or Turbo does not
  # navigate.
  test "a Turbo form submission lands on the full HTML run page" do
    turbo_accept = { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" }

    post runs_path, params: { run: { input: fixture_file_upload("data_prueba_tecnica.xlsx") } }, headers: turbo_accept
    run = Run.last
    assert_redirected_to run_path(run)
    follow_redirect!(headers: turbo_accept)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_select "html body main h1", "Corrida #{run.id}"
    assert_select "#progress [id^=source_item_]", 5
  end

  test "an invalid file shows a friendly error" do
    post runs_path, params: { run: { input: fixture_file_upload("not_excel.txt") } }

    assert_response :unprocessable_entity
    assert_select ".error", /Excel/
  end

  test "submitting without a file shows a friendly error" do
    post runs_path, params: { run: { input: "" } }

    assert_response :unprocessable_entity
    assert_select ".error", /archivo/
  end

  # Manual verification finding: the page catches up with the current state
  # once its stream subscription is confirmed (catch-up controller).
  test "the run page asks to catch up once subscribed" do
    run = Run.create!(status: "processing")

    get run_path(run)

    assert_select "turbo-cable-stream-source[data-controller=catch-up][data-catch-up-url-value=?]", progress_run_path(run)
    assert_select "#progress[data-status=processing] table.items"
  end

  test "the progress endpoint returns the current progress as a turbo stream" do
    run = Run.create!(status: "processing")
    item = run.source_items.create!(position: 0, part_number: "RM-152", manufacturer: "REXITE", status: "done")

    get progress_run_path(run), headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_select "turbo-stream[action=replace][target=progress]"
    assert_includes response.body, %(id="source_item_#{item.id}" class="status-done")
    assert_includes response.body, "listo"
  end

  test "a finished run offers the download" do
    run = Run.create!(status: "done")
    run.output.attach(io: StringIO.new("xlsx"), filename: "catalogo.xlsx")

    get run_path(run)

    assert_select "#download a[href]", /Descargar Excel/
  end
end
