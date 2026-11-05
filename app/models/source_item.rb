class SourceItem < ApplicationRecord
  STATUSES = %w[pending fetching done not_found error].freeze

  belongs_to :run

  validates :status, inclusion: { in: STATUSES }
  validates :part_number, presence: true
end
