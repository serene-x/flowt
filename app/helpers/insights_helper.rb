module InsightsHelper
  def trend_indicator(current, previous, format: :decimal)
    return content_tag(:span, "→", class: "text-stone-300 text-sm") if current.nil? || previous.nil?

    direction = ThresholdService.trend_direction(current, previous)
    rel = ThresholdService.relative_change(current, previous)
    arrow = case direction
            when :up then "↑"
            when :down then "↓"
            else "→"
            end
    color = case direction
            when :up then "text-emerald-600"
            when :down then "text-rose-600"
            else "text-stone-400"
            end
    pct_text = rel ? "#{rel.positive? ? '+' : ''}#{(rel * 100).round(1)}%" : ""
    content_tag(:span, "#{arrow} #{pct_text}", class: "inline-flex items-center gap-1 text-xs font-semibold #{color} tabular-nums")
  end

  def threshold_badge(band)
    return "" if band == :unknown

    content_tag(:span, ThresholdService.band_emoji(band),
                class: "text-xs", title: band.to_s.titleize)
  end

  def insight_card_classes(severity)
    base = "rounded-xl border p-4 flex flex-col gap-1"
    "#{base} #{ThresholdService.severity_classes(severity)}"
  end

  def priority_badge(priority)
    content_tag(:span, priority.to_s.upcase,
                class: "inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-bold tracking-wider #{ThresholdService.priority_classes(priority)}")
  end

  def metric_periods_for(department, section, key)
    by_date = department.department_profile&.snapshot_data&.dig(section, "by_date") || {}
    values = by_date.values.compact
    return [nil, nil] if values.size < 2

    [values.last, values[-2]]
  end

  def department_periods(department)
    by_month = department_history_by_month(department)
    {
      engagement: extract_period(by_month, :engagement),
      attendance: extract_period(by_month, :attendance),
      headcount: extract_period(by_month, :headcount),
      sentiment: extract_period(by_month, :sentiment)
    }
  end

  private

  def department_history_by_month(department)
    eng_rows = DataRow.joins(:dataset)
                      .where(datasets: { dataset_type: Dataset.dataset_types["engagement"] })
                      .where("data->>'department' = ?", department.name)
                      .to_a
    eng_by_month = eng_rows.group_by { |r| r.data["survey_date"].to_s[0, 7] }
                           .reject { |k, _| k.blank? }
                           .transform_values do |grp|
                             vals = grp.map { |r| Float(r.data["engagement_score"]) rescue nil }.compact
                             headcount = grp.map { |r| r.data["employee_id"] }.compact.uniq.size
                             { engagement: vals.empty? ? nil : vals.sum / vals.size.to_f, headcount: headcount }
                           end.sort.to_h

    event_rows = DataRow.joins(:dataset)
                        .where(datasets: { dataset_type: Dataset.dataset_types["events"] })
                        .where("data->>'department' = ?", department.name)
                        .to_a
    att_by_month = event_rows.group_by { |r| r.data["event_date"].to_s[0, 7] }
                             .reject { |k, _| k.blank? }
                             .transform_values do |grp|
                               vals = grp.map { |r| Float(r.data["attendance_rate"]) rescue nil }.compact
                               vals.empty? ? nil : vals.sum / vals.size.to_f
                             end.sort.to_h

    { engagement: eng_by_month, attendance: att_by_month }
  end

  def extract_period(by_month, kind)
    case kind
    when :engagement
      values = by_month[:engagement].values.map { |h| h[:engagement] }.compact
      values.size >= 2 ? [values.last, values[-2]] : [nil, nil]
    when :headcount
      values = by_month[:engagement].values.map { |h| h[:headcount] }.compact
      values.size >= 2 ? [values.last, values[-2]] : [nil, nil]
    when :attendance
      values = by_month[:attendance].values.compact
      values.size >= 2 ? [values.last, values[-2]] : [nil, nil]
    else [nil, nil]
    end
  end
end
