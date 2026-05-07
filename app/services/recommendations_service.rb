class RecommendationsService
  Recommendation = Struct.new(:priority, :action, :rationale, keyword_init: true) do
    def to_h
      { priority: priority, action: action, rationale: rationale }
    end

    def priority_rank
      { high: 0, medium: 1, low: 2 }.fetch(priority, 3)
    end
  end

  PRIORITY_ORDER = { high: 0, medium: 1, low: 2 }.freeze

  def self.call(department, insight_cards: nil)
    new(department, insight_cards: insight_cards).call
  end

  def initialize(department, insight_cards: nil)
    @department = department
    @snapshot = department.department_profile&.snapshot_data || {}
    @insight_cards = insight_cards || InsightEngineService.call(department)
  end

  def call
    recs = []
    recs.concat(turnover_engagement_combo)
    recs.concat(turnover_tenure_combo)
    recs.concat(attendance_low)
    recs.concat(negative_sentiment_keyword)
    recs.concat(engagement_consecutive_decline)
    recs.concat(channel_dominance)
    recs.concat(all_clear)

    recs = recs.sort_by(&:priority_rank).first(4)
    recs
  end

  private

  attr_reader :snapshot, :insight_cards

  def turnover_engagement_combo
    rate = snapshot.dig("turnover", "rate")
    eng = snapshot.dig("engagement", "average")
    return [] unless rate && eng && rate > 0.20 && eng < ThresholdService::ENGAGEMENT_CRITICAL

    [Recommendation.new(
      priority: :high,
      action: "Run a pulse survey focused on manager satisfaction and workload clarity",
      rationale: "Turnover at #{(rate * 100).round(1)}% combined with engagement of #{eng.round(2)} suggests a leadership or workload root cause."
    )]
  end

  def turnover_tenure_combo
    rate = snapshot.dig("turnover", "rate")
    avg_tenure = snapshot.dig("turnover", "average_tenure_months")
    return [] unless rate && avg_tenure && rate > 0.20 && avg_tenure < 12

    [Recommendation.new(
      priority: :high,
      action: "Investigate onboarding experience — high turnover is concentrated in first-year employees",
      rationale: "Average tenure at exit is only #{avg_tenure.round(1)} months with a #{(rate * 100).round(1)}% turnover rate."
    )]
  end

  def attendance_low
    rate = snapshot.dig("events", "attendance_rate")
    return [] unless rate && rate < ThresholdService::ATTENDANCE_WARNING

    [Recommendation.new(
      priority: :medium,
      action: "Switch to async communication formats for this department — attendance data suggests low preference for live events",
      rationale: "Average event attendance is only #{(rate * 100).round(1)}%."
    )]
  end

  def negative_sentiment_keyword
    breakdown = snapshot.dig("feedback", "sentiment_breakdown") || {}
    total = breakdown.values.map(&:to_i).sum
    return [] if total.zero?

    neg_share = breakdown["negative"].to_i / total.to_f
    return [] unless neg_share > ThresholdService::SENTIMENT_NEGATIVE_WARNING

    themes = snapshot.dig("feedback", "themes") || []
    keyword = themes.first&.dig("term")
    return [] unless keyword

    [Recommendation.new(
      priority: :high,
      action: "Flag '#{keyword}' theme for immediate communications review",
      rationale: "Negative sentiment is at #{(neg_share * 100).round(0)}% and '#{keyword}' is the most-mentioned theme."
    )]
  end

  def engagement_consecutive_decline
    by_date = snapshot.dig("engagement", "by_date") || {}
    values = by_date.values.compact.map(&:to_f)
    return [] if values.size < 3

    last_three = values.last(3)
    declining = last_three.each_cons(2).all? { |a, b| b < a }
    return [] unless declining

    [Recommendation.new(
      priority: :high,
      action: "Escalate to HR leadership — engagement has declined consistently across multiple periods",
      rationale: "Engagement dropped across the last 3 periods: #{last_three.map { |v| v.round(2) }.join(' → ')}."
    )]
  end

  def channel_dominance
    distribution = snapshot.dig("communications", "channel_distribution") || {}
    total = distribution.values.sum
    return [] if total.zero?

    top_channel, top_count = distribution.max_by { |_, c| c }
    share = top_count.to_f / total
    return [] unless share > ThresholdService::CHANNEL_DOMINANT_SHARE

    [Recommendation.new(
      priority: :medium,
      action: "Consolidate communications to #{top_channel} — this department has a strong stated preference",
      rationale: "#{(share * 100).round(0)}% of respondents prefer #{top_channel}."
    )]
  end

  def all_clear
    eng = snapshot.dig("engagement", "average")
    att = snapshot.dig("events", "attendance_rate")
    breakdown = snapshot.dig("feedback", "sentiment_breakdown") || {}
    total = breakdown.values.map(&:to_i).sum
    neg_share = total.zero? ? 1.0 : breakdown["negative"].to_i / total.to_f

    return [] unless eng && att &&
                     eng >= ThresholdService::ENGAGEMENT_HEALTHY &&
                     att >= ThresholdService::ATTENDANCE_HEALTHY &&
                     neg_share < ThresholdService::SENTIMENT_NEGATIVE_WARNING

    [Recommendation.new(
      priority: :low,
      action: "No immediate actions needed — this department is performing well across all indicators",
      rationale: "Engagement #{eng.round(2)}, attendance #{(att * 100).round(0)}%, and negative sentiment under #{(ThresholdService::SENTIMENT_NEGATIVE_WARNING * 100).round(0)}%."
    )]
  end
end
