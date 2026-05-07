class CreateAiSummaries < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_summaries do |t|
      t.references :department, null: false, foreign_key: true, index: { unique: true }
      t.text :summary_text, null: false
      t.datetime :generated_at, null: false
      t.string :data_fingerprint, null: false
      t.string :source, null: false, default: "claude"

      t.timestamps
    end

    add_index :ai_summaries, :data_fingerprint
  end
end
