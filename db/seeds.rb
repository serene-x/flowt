return if ENV["SKIP_SEEDS"] == "1"

samples = [
  { name: "Q1 + Q2 Engagement Survey", file: "engagement.csv", type: "engagement" },
  { name: "2025 Turnover Report",      file: "turnover.csv",   type: "turnover" },
  { name: "All-Hands & Workshop Attendance", file: "events.csv", type: "events" },
  { name: "Quarterly Feedback Form",   file: "feedback.csv",   type: "feedback" }
]

departments_seen = Set.new

samples.each do |sample|
  if Dataset.exists?(name: sample[:name])
    puts "skipping #{sample[:name]} (already imported)"
    next
  end

  dataset = Dataset.create!(
    name: sample[:name],
    dataset_type: sample[:type],
    original_filename: sample[:file],
    status: :pending
  )

  csv_text = File.read(Rails.root.join("db/sample_csvs", sample[:file]))
  DatasetImportService.call(dataset, csv_text)

  dataset.reload
  if dataset.dataset_columns.exists?(name: "department")
    dataset.data_rows.pluck(Arel.sql("data->>'department'")).compact.uniq.each do |name|
      departments_seen << name
    end
  end

  puts "imported #{sample[:name]} (#{dataset.row_count} rows, status: #{dataset.status})"
end

departments_seen.each { |raw| Department.find_or_create_by_name(raw) }

Department.find_each { |department| DepartmentProfileService.refresh(department) }

puts "Seed complete: #{Department.count} departments, #{Dataset.count} datasets, #{DataRow.count} rows"
