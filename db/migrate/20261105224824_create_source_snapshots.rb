class CreateSourceSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :source_snapshots do |t|
      t.string :url, null: false
      t.binary :body, null: false
      t.string :content_type
      t.string :sha256, null: false
      t.datetime :fetched_at, null: false
      t.timestamps
    end
    add_index :source_snapshots, :url, unique: true
  end
end
