class DatasetsController < ApplicationController
  ROWS_PREVIEW_LIMIT = 15

  before_action :load_dataset, only: [:show, :destroy, :preview, :export, :assign_department]

  def index
    @datasets = Dataset.recent.includes(:department, :dataset_columns)
  end

  def new
    @dataset = Dataset.new
  end

  def create
    file = params.dig(:dataset, :file)
    return redirect_to new_dataset_path, alert: "Please choose a CSV file." if file.blank?

    name = params.dig(:dataset, :name).presence || File.basename(file.original_filename, ".*")
    dataset_type = params.dig(:dataset, :dataset_type) || "custom"

    dataset = Dataset.create!(
      name: name,
      dataset_type: dataset_type,
      original_filename: file.original_filename,
      status: :pending
    )

    csv_text = file.read
    job = ImportJob.create!(dataset: dataset, status: "queued", current_step: "Queued")
    if Rails.env.test? || ENV["IMPORT_INLINE"] == "1"
      ProgressiveDatasetImportService.call(dataset, csv_text, job)
    else
      ImportDatasetJob.perform_later(dataset.id, csv_text, import_job_id: job.id)
    end
    redirect_to import_job_path(job)
  rescue StandardError => e
    redirect_to new_dataset_path, alert: "Import failed: #{e.message}"
  end

  def show
    @columns = @dataset.dataset_columns
    @log = @dataset.latest_log
    @rows_preview = @dataset.data_rows.limit(ROWS_PREVIEW_LIMIT)
  end

  def destroy
    @dataset.destroy
    redirect_to datasets_path, notice: "Dataset removed."
  end

  def preview
    csv_text = params[:dataset][:file].read
    @parsed = CsvParserService.call(StringIO.new(csv_text))
    render partial: "preview", locals: { parsed: @parsed }
  end

  def export
    headers = @dataset.dataset_columns.order(:position).map(&:name)
    csv_data = CSV.generate do |csv|
      csv << headers
      @dataset.data_rows.find_each { |row| csv << headers.map { |h| row.data[h] } }
    end
    send_data csv_data, type: "text/csv", filename: "#{@dataset.name.parameterize}.csv"
  end

  def assign_department
    department = Department.find_or_create_by_name(params[:department_name])
    @dataset.update!(department: department)
    DepartmentProfileService.refresh(department) if department
    redirect_to dataset_path(@dataset), notice: "Linked to #{department&.name || 'department'}."
  end

  private

  def load_dataset
    @dataset = Dataset.find(params[:id])
  end
end
