class AiSummary < ApplicationRecord
  belongs_to :department

  validates :summary_text, :generated_at, :data_fingerprint, :source, presence: true
end
