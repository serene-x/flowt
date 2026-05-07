class ProgressiveDatasetImportService
  def self.call(dataset, csv_text, import_job)
    new(dataset, csv_text, import_job).call
  end

  def initialize(dataset, csv_text, import_job)
    @dataset = dataset
    @csv_text = csv_text
    @job = import_job
  end

  def call
    @job.mark_started!
    @dataset.update!(status: :processing)

    @job.update_step!("Parsing CSV")
    parsed = CsvParserService.call(StringIO.new(@csv_text))

    if parsed.headers.empty? || parsed.total_rows.zero?
      @dataset.update!(status: :failed)
      ImportLog.create!(dataset: @dataset, summary: { imported: 0, skipped: 0 },
                        warnings: parsed.warnings, cleaning_diff: [])
      @job.mark_failed!("CSV had no usable rows")
      return false
    end

    @job.update_step!("Running cleaning pipeline")
    cleaned = DataCleaningPipeline.call(parsed.rows, parsed.columns)

    ActiveRecord::Base.transaction do
      @dataset.dataset_columns.destroy_all
      @dataset.data_rows.destroy_all

      parsed.columns.each do |col|
        @dataset.dataset_columns.create!(
          name: col[:name], position: col[:position],
          data_type: DatasetColumn.data_types[col[:data_type]], stats: {}
        )
      end

      cleaned.rows.each_with_index do |row, idx|
        flags = row.delete("__flags__") || []
        @dataset.data_rows.create!(
          row_index: idx, data: row,
          flags: { "items" => flags, "flagged" => flags.any? }
        )
      end

      @dataset.update!(
        row_count: cleaned.rows.size,
        skipped_count: parsed.total_rows - cleaned.rows.size,
        status: :ready,
        imported_at: Time.current
      )

      ImportLog.create!(
        dataset: @dataset,
        summary: {
          imported: cleaned.rows.size,
          skipped: parsed.total_rows - cleaned.rows.size,
          total_rows: parsed.total_rows
        },
        warnings: parsed.warnings,
        cleaning_diff: cleaned.diff
      )
    end

    @job.update_step!("Computing column stats")
    compute_column_stats!

    @job.update_step!("Updating department profiles")
    departments = refresh_dependent_profiles

    @job.update_step!("Generating insights")
    departments.each { |d| InsightEngineService.call(d) }

    @job.update_step!("Generating AI summary")
    departments.each { |d| AiSummaryService.call(d) rescue nil }

    @job.mark_complete!
    true
  rescue StandardError => e
    @dataset.update!(status: :failed)
    ImportLog.create!(
      dataset: @dataset,
      summary: { imported: 0, skipped: 0, error: e.message },
      warnings: [{ kind: "exception", message: e.message }],
      cleaning_diff: []
    )
    @job.mark_failed!(e.message)
    raise
  end

  private

  def compute_column_stats!
    @dataset.reload
    @dataset.dataset_columns.each do |col|
      stats = AnalyticsService.column_stats(col, @dataset.data_rows.to_a)
      col.update!(stats: stats)
    end
  end

  def refresh_dependent_profiles
    departments = if @dataset.department
      [@dataset.department]
    else
      detected_departments_from_rows
    end

    departments = departments.compact.uniq
    departments.each { |d| DepartmentProfileService.refresh(d) }
    departments
  end

  def detected_departments_from_rows
    return [] unless @dataset.dataset_columns.exists?(name: "department")

    @dataset.data_rows.pluck(Arel.sql("data->>'department'"))
            .compact.uniq
            .map { |name| Department.find_or_create_by_name(name) }
  end
end
