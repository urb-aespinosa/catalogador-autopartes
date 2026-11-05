class Run < ApplicationRecord
  STATUSES = %w[pending processing finalizing done failed].freeze

  has_one_attached :input
  has_one_attached :output
  has_many :source_items, -> { order(:position) }, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  # Called when an item finishes. The conditional UPDATE is atomic, so only
  # the job that moves the run from processing to finalizing enqueues the
  # workbook, exactly once.
  def finalize_if_complete!
    return if source_items.where(status: %w[pending fetching]).exists?

    moved = Run.where(id: id, status: "processing").update_all(status: "finalizing", updated_at: Time.current)
    FinalizeRunJob.perform_later(self) if moved == 1
  end

  # Reads the uploaded workbook first so an invalid file never creates a run.
  def self.create_from_upload!(io, filename)
    rows = Catalog::SourceWorkbook.read(io.path)
    io.rewind

    transaction do
      run = create!
      run.input.attach(io: io, filename: filename)
      rows.each { |row| run.source_items.create!(row) }
      run
    end
  end
end
