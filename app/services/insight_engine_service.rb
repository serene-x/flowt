class InsightEngineService
  Card = Struct.new(:severity, :finding, :stat, keyword_init: true) do
    def to_h
      { severity: severity, finding: finding, stat: stat }
    end
  end

  def self.call(department, company_averages: nil)
    new(department, company_averages: company_averages).call
  end

  def initialize(department, company_averages: nil)
    @department = department
    @snapshot = department.department_profile&.snapshot_data || {}
    @company_averages = company_averages || compute_company_averages
  end

  def call
    cards = []
    cards.concat(turnover_cards)
    cards.concat(engagement_cards)
    cards.concat(attendance_cards)
    cards.concat(sentiment_cards)
    cards.concat(headcount_cards)
    cards
  end

  private

  attr_reader :snapshot, :company_averages

  def turnover_cards
    rate = snapshot.dig("turnover", "rate")
    return [] if rate.nil?

    exits = snapshot.dig("turnover", "exits").to_i
    return [] if exits < 3

    company_avg = company_averages[:turnover]
    cards = []

    above_avg = company_avg ? (rate - company_avg) : nil

    if above_avg && above_avg > ThresholdService::TURNOVER_CRITICAL_ABOVE_AVG
      cards << Card.new(severity: :critical,
                        finding: "Turnover is significantly above company average",
                        stat: format_pct_with_avg(rate, company_avg))
    elsif above_avg && above_avg > ThresholdService::TURNOVER_WARNING_ABOVE_AVG
      cards << Card.new(severity: :warning,
                        finding: "Turnover is above company average",
                        stat: format_pct_with_avg(rate, company_avg))
    elsif rate < ThresholdService::TURNOVER_HEALTHY
      cards << Card.new(severity: :positive,
                        finding: "Turnover is well below company average",
                        stat: format_pct_with_avg(rate, company_avg))
    end

    cards
  end

  def engagement_cards
    score = snapshot.dig("engagement", "average")
    return [] if score.nil?

    sample_size = snapshot.dig("engagement", "sample_size").to_i
    return [] if sample_size < 5

    cards = []
    if score < ThresholdService::ENGAGEMENT_CRITICAL
      cards << Card.new(severity: :critical,
                        finding: "Engagement is below acceptable threshold",
                        stat: "#{score.round(2)} / 5.0")
    end

    current, previous = engagement_periods
    if current && previous
      change = (current - previous) / previous.abs.to_f
      if change < -ThresholdService::ENGAGEMENT_TREND_DROP
        cards << Card.new(severity: :warning,
                          finding: "Engagement has declined significantly since last period",
                          stat: "#{previous.round(2)} → #{current.round(2)} (#{(change * 100).round(1)}%)")
      elsif change > ThresholdService::ENGAGEMENT_TREND_RISE
        cards << Card.new(severity: :positive,
                          finding: "Engagement is trending upward",
                          stat: "#{previous.round(2)} → #{current.round(2)} (+#{(change * 100).round(1)}%)")
      end
    end

    cards
  end

  def attendance_cards
    rate = snapshot.dig("events", "attendance_rate")
    return [] if rate.nil?

    cards = []
    cards << Card.new(severity: :warning,
                      finding: "Event attendance is low",
                      stat: format_pct(rate)) if rate < ThresholdService::ATTENDANCE_WARNING

    current, previous = attendance_periods
    if current && previous && previous.positive?
      change = (current - previous) / previous.abs.to_f
      if change < -ThresholdService::ATTENDANCE_TREND_DROP
        cards << Card.new(severity: :critical,
                          finding: "Event attendance has dropped sharply",
                          stat: "#{format_pct(previous)} → #{format_pct(current)}")
      end
    end

    cards
  end

  def sentiment_cards
    breakdown = snapshot.dig("feedback", "sentiment_breakdown")
    return [] if breakdown.blank?

    total = breakdown.values.map(&:to_i).sum
    return [] if total.zero?

    neg_share = breakdown["negative"].to_i / total.to_f
    pos_share = breakdown["positive"].to_i / total.to_f

    cards = []
    if neg_share > ThresholdService::SENTIMENT_NEGATIVE_CRITICAL
      cards << Card.new(severity: :critical,
                        finding: "Majority of feedback is negative",
                        stat: "#{(neg_share * 100).round(0)}% negative across #{total} responses")
    elsif neg_share > ThresholdService::SENTIMENT_NEGATIVE_WARNING
      cards << Card.new(severity: :warning,
                        finding: "Negative sentiment is elevated",
                        stat: "#{(neg_share * 100).round(0)}% negative across #{total} responses")
    end

    if pos_share > ThresholdService::SENTIMENT_POSITIVE_HEALTHY
      cards << Card.new(severity: :positive,
                        finding: "Feedback sentiment is strongly positive",
                        stat: "#{(pos_share * 100).round(0)}% positive across #{total} responses")
    end

    cards
  end

  def headcount_cards
    current, previous = headcount_periods
    return [] unless current && previous && previous.positive?

    change = (current - previous) / previous.to_f
    return [] unless change < -ThresholdService::HEADCOUNT_DROP_WARNING

    [Card.new(severity: :warning,
              finding: "Headcount has decreased significantly",
              stat: "#{previous} → #{current} (#{(change * 100).round(1)}%)")]
  end

  def engagement_periods
    by_date = snapshot.dig("engagement", "by_date") || {}
    values = by_date.values.compact
    return [nil, nil] if values.size < 3

    [values.last.to_f, values[-2].to_f]
  end

  def attendance_periods
    return [nil, nil] unless @department.relevant_datasets.any?

    rows = DataRow.joins(:dataset)
                  .where(datasets: { dataset_type: Dataset.dataset_types["events"] })
                  .where("data->>'department' = ?", @department.name)
                  .to_a
    by_month = rows.group_by { |r| r.data["event_date"].to_s[0, 7] }
                   .reject { |k, _| k.blank? }
                   .transform_values do |grp|
                     vals = grp.map { |r| Float(r.data["attendance_rate"]) rescue nil }.compact
                     vals.empty? ? nil : vals.sum / vals.size.to_f
                   end
                   .compact
                   .sort.to_h
    values = by_month.values
    return [nil, nil] if values.size < 3

    [values.last.to_f, values[-2].to_f]
  end

  def headcount_periods
    rows = DataRow.joins(:dataset)
                  .where(datasets: { dataset_type: Dataset.dataset_types["engagement"] })
                  .where("data->>'department' = ?", @department.name)
                  .to_a
    return [nil, nil] if rows.empty?

    by_month = rows.group_by { |r| r.data["survey_date"].to_s[0, 7] }
                   .reject { |k, _| k.blank? }
                   .transform_values { |grp| grp.map { |r| r.data["employee_id"] }.compact.uniq.size }
                   .sort.to_h
    values = by_month.values
    return [nil, nil] if values.size < 3

    [values.last, values[-2]]
  end

  def compute_company_averages
    self.class.company_averages
  end

  def self.company_averages
    rates = Department.includes(:department_profile).filter_map do |d|
      snap = d.department_profile&.snapshot_data
      next unless snap&.dig("turnover", "exits").to_i >= 3

      snap.dig("turnover", "rate")
    end
    eng = Department.includes(:department_profile).filter_map do |d|
      snap = d.department_profile&.snapshot_data
      next unless snap&.dig("engagement", "sample_size").to_i >= 5

      snap.dig("engagement", "average")
    end
    att = Department.includes(:department_profile).filter_map do |d|
      d.department_profile&.snapshot_data&.dig("events", "attendance_rate")
    end
    {
      turnover: rates.empty? ? nil : rates.sum / rates.size.to_f,
      engagement: eng.empty? ? nil : eng.sum / eng.size.to_f,
      attendance: att.empty? ? nil : att.sum / att.size.to_f
    }
  end

  def format_pct(value)
    return "—" if value.nil?

    "#{(value * 100).round(1)}%"
  end

  def format_pct_with_avg(value, avg)
    return format_pct(value) if avg.nil?

    "#{format_pct(value)} vs #{format_pct(avg)} company avg"
  end
end
