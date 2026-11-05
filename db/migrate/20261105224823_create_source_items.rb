class CreateSourceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :source_items do |t|
      t.references :run, null: false, foreign_key: true
      t.integer :position, null: false
      t.string :status, null: false, default: "pending"
      t.string :internal_code
      t.string :part_number, null: false
      t.string :item_description
      t.string :description
      t.string :item_group
      t.string :manufacturer
      t.string :unit
      t.string :product
      t.json :result, null: false, default: {}
      t.timestamps
    end
    add_index :source_items, [ :run_id, :position ], unique: true
  end
end
