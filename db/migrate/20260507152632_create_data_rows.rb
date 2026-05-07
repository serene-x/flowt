class CreateDataRows < ActiveRecord::Migration[7.1]
  def change
    create_table :data_rows do |t|
      t.references :dataset, null: false, foreign_key: true
      t.integer :row_index, null: false
      t.jsonb :data, null: false, default: {}
      t.jsonb :flags, null: false, default: {}

      t.timestamps
    end

    add_index :data_rows, [:dataset_id, :row_index]
  end
end
