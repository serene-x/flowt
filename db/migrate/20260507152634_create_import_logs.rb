class CreateImportLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :import_logs do |t|
      t.references :dataset, null: false, foreign_key: true
      t.jsonb :summary, null: false, default: {}
      t.jsonb :warnings, null: false, default: []
      t.jsonb :cleaning_diff, null: false, default: []

      t.timestamps
    end
  end
end
