class Run < ApplicationRecord
  STATUSES = %w[pending processing finalizing done failed].freeze

  has_one_attached :input
  has_one_attached :output
  has_many :source_items, -> { order(:position) }, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

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
