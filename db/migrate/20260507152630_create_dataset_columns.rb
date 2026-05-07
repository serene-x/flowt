class CreateDatasetColumns < ActiveRecord::Migration[7.1]
  def change
    create_table :dataset_columns do |t|
      t.references :dataset, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.integer :data_type, null: false, default: 3
      t.jsonb :stats, null: false, default: {}

      t.timestamps
    end

    add_index :dataset_columns, [:dataset_id, :position], unique: true
  end
end
