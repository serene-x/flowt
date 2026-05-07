class DepartmentProfile < ApplicationRecord
  belongs_to :department

  def section(key)
    snapshot_data.fetch(key.to_s, {})
  end

  def stale?
    refreshed_at.nil? || refreshed_at < ENV.fetch("PROFILE_STALE_AFTER_HOURS", "1").to_i.hours.ago
  end
end
