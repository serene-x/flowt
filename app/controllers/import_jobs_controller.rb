class ImportJobsController < ApplicationController
  JOBS_LIMIT = 40

  def index
    @jobs = ImportJob.includes(dataset: :department).recent.limit(JOBS_LIMIT)
  end

  def show
    @job = ImportJob.includes(:dataset).find(params[:id])
  end
end
