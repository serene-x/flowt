class ImportDatasetJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(dataset_id, csv_text, import_job_id: nil)
    dataset = Dataset.find(dataset_id)
    job = import_job_id ? ImportJob.find(import_job_id) : nil

    if job
      ProgressiveDatasetImportService.call(dataset, csv_text, job)
    else
      DatasetImportService.call(dataset, csv_text)
    end
  end
end
