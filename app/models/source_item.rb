class SourceItem < ApplicationRecord
  STATUSES = %w[pending fetching done not_found no_source error].freeze
  STATUS_LABELS = {
    "pending" => "pendiente", "fetching" => "consultando fuente", "done" => "listo",
    "not_found" => "no encontrado", "no_source" => "sin fuente configurada", "error" => "error"
  }.freeze

  belongs_to :run

  # Live progress on the run page (spec §6.6).
  after_update_commit -> { broadcast_replace_to run, target: self, partial: "runs/item", locals: { item: self } }

  validates :status, inclusion: { in: STATUSES }
  validates :part_number, presence: true
end
