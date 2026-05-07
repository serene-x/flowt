class ImportJob < ApplicationRecord
  belongs_to :dataset

  STATUSES = %w[queued processing complete failed].freeze
  STEPS = [
    "Parsing CSV",
    "Running cleaning pipeline",
    "Computing column stats",
    "Updating department profiles",
    "Generating insights",
    "Generating AI summary"
  ].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def progress_for(step_name)
    return progress_percent unless step_name

    idx = STEPS.index(step_name) || 0
    ((idx + 1).to_f / STEPS.size * 100).round
  end

  def update_step!(step_name)
    update!(current_step: step_name, progress_percent: progress_for(step_name))
    broadcast_status
  end

  def mark_started!
    update!(status: "processing", started_at: Time.current, attempt_count: attempt_count + 1)
    broadcast_status
  end

  def mark_complete!
    update!(status: "complete", progress_percent: 100, finished_at: Time.current, current_step: nil)
    broadcast_status
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message, finished_at: Time.current)
    broadcast_status
  end

  def broadcast_status
    Turbo::StreamsChannel.broadcast_replace_to(
      "import_job_#{id}",
      target: "import_job_status",
      partial: "import_jobs/status",
      locals: { job: self }
    )
  rescue StandardError
    nil
  end
end
