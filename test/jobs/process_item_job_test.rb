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
    assert_equal "not_found", run.source_items.find_by(part_number: "TK1283-1").status
  end

  test "finalize is enqueued exactly once" do
    run = run_with_items(statuses: %w[done done])

    assert_enqueued_jobs 1, only: FinalizeRunJob do
      2.times { run.finalize_if_complete! }
    end
    assert_equal "finalizing", run.reload.status
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
end
