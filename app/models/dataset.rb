class Dataset < ApplicationRecord
  belongs_to :department, optional: true
  has_many :dataset_columns, -> { order(:position) }, dependent: :destroy, inverse_of: :dataset
  has_many :data_rows, -> { order(:row_index) }, dependent: :destroy, inverse_of: :dataset
  has_many :import_logs, dependent: :destroy

  enum :dataset_type, {
    engagement: 0,
    turnover: 1,
    events: 2,
    feedback: 3,
    communications: 4,
    custom: 5
  }

  enum :status, {
    pending: 0,
    processing: 1,
    ready: 2,
    failed: 3
  }, prefix: true

  validates :name, presence: true
  validates :dataset_type, presence: true

  scope :recent, -> { order(created_at: :desc) }

  def latest_log
    import_logs.order(created_at: :desc).first
  end
end
