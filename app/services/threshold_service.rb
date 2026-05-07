class ThresholdService
  TURNOVER_CRITICAL_ABOVE_AVG = 0.15  # 15+ percentage points above company avg
  TURNOVER_WARNING_ABOVE_AVG  = 0.07  # 7+ percentage points above company avg
  TURNOVER_HEALTHY = 0.10

  ENGAGEMENT_CRITICAL = 3.0
  ENGAGEMENT_HEALTHY = 4.0
  ENGAGEMENT_TREND_DROP = 0.15
  ENGAGEMENT_TREND_RISE = 0.15

  ATTENDANCE_WARNING = 0.40
  ATTENDANCE_HEALTHY = 0.75
  ATTENDANCE_TREND_DROP = 0.30

  SENTIMENT_NEGATIVE_CRITICAL = 0.50
  SENTIMENT_NEGATIVE_WARNING = 0.30
  SENTIMENT_POSITIVE_HEALTHY = 0.70

  HEADCOUNT_DROP_WARNING = 0.20

  TREND_NEUTRAL_BAND = 0.05
  CHANNEL_DOMINANT_SHARE = 0.60

  def self.turnover_band(rate, company_avg: nil)
    return :unknown if rate.nil?
    if company_avg
      above = rate - company_avg
      return :critical if above > TURNOVER_CRITICAL_ABOVE_AVG
      return :warning  if above > TURNOVER_WARNING_ABOVE_AVG
    end
    return :healthy if rate < TURNOVER_HEALTHY

    :neutral
  end

  def self.engagement_band(score)
    return :unknown if score.nil?
    return :critical if score < ENGAGEMENT_CRITICAL
    return :healthy if score >= ENGAGEMENT_HEALTHY

    :neutral
  end

  def self.attendance_band(rate)
    return :unknown if rate.nil?
    return :warning if rate < ATTENDANCE_WARNING
    return :healthy if rate >= ATTENDANCE_HEALTHY

    :neutral
  end

  def self.sentiment_band(breakdown)
    return :unknown if breakdown.blank?

    total = breakdown.values.map(&:to_i).sum
    return :unknown if total.zero?

    neg_share = breakdown["negative"].to_i / total.to_f
    pos_share = breakdown["positive"].to_i / total.to_f

    return :critical if neg_share > SENTIMENT_NEGATIVE_CRITICAL
    return :warning if neg_share > SENTIMENT_NEGATIVE_WARNING
    return :healthy if pos_share > SENTIMENT_POSITIVE_HEALTHY

    :neutral
  end

  def self.trend_direction(current, previous)
    return :flat if current.nil? || previous.nil? || previous.zero?

    change = (current - previous) / previous.abs.to_f
    return :up if change > TREND_NEUTRAL_BAND
    return :down if change < -TREND_NEUTRAL_BAND

    :flat
  end

  def self.relative_change(current, previous)
    return nil if current.nil? || previous.nil? || previous.zero?

    (current - previous) / previous.abs.to_f
  end

  def self.band_color_classes(band)
    case band
    when :critical then "bg-rose-50 border-rose-200 text-rose-700"
    when :warning then "bg-amber-50 border-amber-200 text-amber-700"
    when :healthy then "bg-emerald-50 border-emerald-200 text-emerald-700"
    else "bg-stone-50 border-stone-200 text-stone-700"
    end
  end

  def self.band_emoji(band)
    case band
    when :critical then "🔴"
    when :warning then "🟡"
    when :healthy then "🟢"
    else "⚪"
    end
  end

  def self.severity_emoji(severity)
    case severity
    when :critical then "🔴"
    when :warning then "🟡"
    when :positive then "🟢"
    else "⚪"
    end
  end

  def self.severity_classes(severity)
    case severity
    when :critical then "bg-rose-50 border-rose-200 text-rose-800"
    when :warning then "bg-amber-50 border-amber-200 text-amber-800"
    when :positive then "bg-emerald-50 border-emerald-200 text-emerald-800"
    else "bg-stone-50 border-stone-200 text-stone-800"
    end
  end

  def self.priority_classes(priority)
    case priority
    when :high then "bg-rose-100 text-rose-800"
    when :medium then "bg-amber-100 text-amber-800"
    when :low then "bg-emerald-100 text-emerald-800"
    else "bg-stone-100 text-stone-700"
    end
  end
end
