class CreateDatasets < ActiveRecord::Migration[7.1]
  def change
    create_table :datasets do |t|
      t.string :name, null: false
      t.integer :dataset_type, null: false, default: 5
      t.references :department, null: true, foreign_key: true
      t.string :original_filename
      t.integer :row_count, default: 0
      t.integer :skipped_count, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :imported_at

      t.timestamps
    end

    add_index :datasets, :dataset_type
    add_index :datasets, :status
  end
end
