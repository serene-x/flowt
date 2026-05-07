class ImportLog < ApplicationRecord
  belongs_to :dataset

  def imported_count
    summary["imported"].to_i
  end

  def skipped_count
    summary["skipped"].to_i
  end

  def warning_count
    Array(warnings).size
  end

  def cleaning_change_count
    Array(cleaning_diff).sum { |entry| entry["count"].to_i }
  end
end
