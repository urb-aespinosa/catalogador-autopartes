require "test_helper"
require "turbo/broadcastable/test_helper"

class ProcessItemJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup { stub_all_sources_from_fixtures }

  def run_with_items(statuses:)
    run = Run.create!(status: "processing")
    statuses.each_with_index { |status, i| run.source_items.create!(position: i, part_number: "P#{i}", status: status) }
    run
  end

  test "an item status change is broadcast to its run" do
    item = run_with_items(statuses: %w[pending]).source_items.first

    assert_turbo_stream_broadcasts(item.run) { item.update!(status: "fetching") }
  end

  test "processing an item updates it and finalizes when it is the last one" do
    run = File.open(file_fixture("data_prueba_tecnica.xlsx")) { Run.create_from_upload!(_1, "data.xlsx") }
    run.update!(status: "processing")
    run.source_items.where.not(part_number: "TK1283-1").update_all(status: "done")

    assert_enqueued_jobs 1, only: FinalizeRunJob do
      ProcessItemJob.perform_now(run.source_items.find_by(part_number: "TK1283-1"))
    end
    assert_equal "no_source", run.source_items.find_by(part_number: "TK1283-1").status
  end

  test "finalize is enqueued exactly once" do
    run = run_with_items(statuses: %w[done done])

    assert_enqueued_jobs 1, only: FinalizeRunJob do
      2.times { run.finalize_if_complete! }
    end
    assert_equal "finalizing", run.reload.status
  end

  test "an item that ended in error does not block finalize" do
    run = run_with_items(statuses: %w[done error])

    assert_enqueued_jobs(1, only: FinalizeRunJob) { run.finalize_if_complete! }
  end

  test "finalize waits while items are pending" do
    run = run_with_items(statuses: %w[done fetching])

    assert_no_enqueued_jobs(only: FinalizeRunJob) { run.finalize_if_complete! }
  end

  test "finalize attaches the workbook and marks the run done" do
    run = Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx"))
    run.update!(status: "finalizing")

    FinalizeRunJob.perform_now(run)

    assert_equal "done", run.reload.status
    assert run.output.attached?
    assert_equal "catalogo_bonaparte.xlsx", run.output.filename.to_s
  end

  # Manual verification finding: an item broadcast sent before the browser
  # subscribed was lost. The final broadcast replaces the whole progress
  # block, so the page always ends with every item's real state.
  test "finalize replaces the whole progress block with every item and the download" do
    run = Catalog::Pipeline.run(file_fixture("data_prueba_tecnica.xlsx"))
    run.update!(status: "finalizing")

    streams = capture_turbo_stream_broadcasts(run) { FinalizeRunJob.perform_now(run) }

    progress = streams.find { _1["target"] == "progress" }
    assert progress, "no broadcast replaces #progress"
    assert_equal "replace", progress["action"]
    html = progress.at("template").inner_html
    assert_includes html, 'data-status="done"'
    run.source_items.each { assert_includes html, %(id="source_item_#{_1.id}" class="status-#{_1.status}") }
    assert_includes html, "Descargar Excel"
  end
end
