class CreateDepartmentProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :department_profiles do |t|
      t.references :department, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :snapshot_data, null: false, default: {}
      t.datetime :refreshed_at

      t.timestamps
    end
  end
end
