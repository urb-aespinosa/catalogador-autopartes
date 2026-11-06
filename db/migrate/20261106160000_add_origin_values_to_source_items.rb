class AddOriginValuesToSourceItems < ActiveRecord::Migration[8.1]
  def change
    # The Origen row as read, with each cell's type (number or text), so the
    # exported Origen sheet reproduces the input exactly.
    add_column :source_items, :origin_values, :json
  end
end
