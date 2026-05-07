class CreateImportJobs < ActiveRecord::Migration[7.1]
  def change
    create_table :import_jobs do |t|
      t.references :dataset, null: false, foreign_key: true
      t.string :status, null: false, default: "queued"
      t.string :current_step
      t.integer :progress_percent, null: false, default: 0
      t.text :error_message
      t.integer :attempt_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :import_jobs, :status
    add_index :import_jobs, :created_at
  end
end
