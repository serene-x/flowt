class BenchmarkService
  Row = Struct.new(:department, :slug, :name, :headcount, :turnover, :engagement, :attendance,
                   :sentiment_pos_share, :last_updated, keyword_init: true)

  def self.call
    rows = Department.includes(:department_profile).map { |d| build_row(d) }
    averages = compute_averages(rows)
    [rows, averages]
  end

  def self.build_row(department)
    snapshot = department.department_profile&.snapshot_data || {}
    breakdown = snapshot.dig("feedback", "sentiment_breakdown") || {}
    total = breakdown.values.map(&:to_i).sum
    pos_share = total.zero? ? nil : breakdown["positive"].to_i / total.to_f

    Row.new(
      department: department,
      slug: department.slug,
      name: department.name,
      headcount: snapshot.dig("headcount", "total"),
      turnover: snapshot.dig("turnover", "rate"),
      engagement: snapshot.dig("engagement", "average"),
      attendance: snapshot.dig("events", "attendance_rate"),
      sentiment_pos_share: pos_share,
      last_updated: department.department_profile&.refreshed_at
    )
  end

  def self.compute_averages(rows)
    {
      headcount: avg(rows.map(&:headcount).compact),
      turnover: avg(rows.map(&:turnover).compact),
      engagement: avg(rows.map(&:engagement).compact),
      attendance: avg(rows.map(&:attendance).compact),
      sentiment_pos_share: avg(rows.map(&:sentiment_pos_share).compact)
    }
  end

  def self.avg(values)
    return nil if values.empty?

    values.sum.to_f / values.size
  end

  def self.cell_band(metric, value, benchmark)
    return :unknown if value.nil? || benchmark.nil?

    case metric
    when :turnover
      ThresholdService.turnover_band(value)
    when :engagement
      ThresholdService.engagement_band(value)
    when :attendance
      ThresholdService.attendance_band(value)
    when :sentiment
      return :healthy if value > ThresholdService::SENTIMENT_POSITIVE_HEALTHY
      return :critical if value < (1.0 - ThresholdService::SENTIMENT_POSITIVE_HEALTHY) * 0.5

      :neutral
    else
      :neutral
    end
  end
end
