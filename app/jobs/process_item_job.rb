class ProcessItemJob < ApplicationJob
  queue_as :default

  def perform(source_item)
    Catalog::ItemProcessor.call(source_item)
  ensure
    source_item.run.finalize_if_complete!
  end
end
