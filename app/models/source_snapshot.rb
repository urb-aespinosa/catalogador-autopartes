class SourceSnapshot < ApplicationRecord
  validates :url, :sha256, :fetched_at, presence: true
end
