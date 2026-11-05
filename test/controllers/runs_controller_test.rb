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

  test "a finished run offers the download" do
    run = Run.create!(status: "done")
    run.output.attach(io: StringIO.new("xlsx"), filename: "catalogo.xlsx")

    get run_path(run)

    assert_select "#download a[href]", /Descargar Excel/
  end
end
