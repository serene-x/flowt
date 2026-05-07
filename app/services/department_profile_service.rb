class DepartmentProfileService
  def self.refresh(department)
    new(department).refresh
  end

  def initialize(department)
    @department = department
  end

  def refresh
    snapshot = {
      "headcount" => headcount_section,
      "engagement" => engagement_section,
      "turnover" => turnover_section,
      "events" => events_section,
      "communications" => communications_section,
      "feedback" => feedback_section
    }

    profile = @department.department_profile || @department.build_department_profile
    profile.snapshot_data = snapshot
    profile.refreshed_at = Time.current
    profile.save!
    profile
  end

  def self.refresh_all
    Department.find_each { |d| refresh(d) }
  end

  private

  def rows_for_type(type)
    type_id = Dataset.dataset_types[type]
    base_scope = DataRow
                 .joins(:dataset)
                 .where(datasets: { dataset_type: type_id, status: Dataset.statuses[:ready] })

    scope_for_department(base_scope).to_a
  end

  def scope_for_department(scope)
    direct = scope.where(datasets: { department_id: @department.id })
    by_row = scope.where("data->>'department' = ?", @department.name)
    DataRow.from("(#{direct.to_sql} UNION #{by_row.to_sql}) AS data_rows")
  end

  def headcount_section
    rows = rows_for_type("engagement")
    return { "total" => 0, "by_role" => {} } if rows.empty?

    employees = rows.map { |r| r.data["employee_id"] }.compact.uniq
    by_role = rows.map { |r| r.data["role"] }.compact.tally
    { "total" => employees.size, "by_role" => by_role }
  end

  def engagement_section
    rows = rows_for_type("engagement")
    return {} if rows.empty?

    eng = numeric_values(rows, "engagement_score")
    sat = numeric_values(rows, "satisfaction_score")

    {
      "average" => mean(eng),
      "satisfaction_average" => mean(sat),
      "sample_size" => eng.size,
      "by_date" => trend_by_month(rows, "survey_date", "engagement_score"),
      "satisfaction_by_date" => trend_by_month(rows, "survey_date", "satisfaction_score"),
      "by_role" => avg_by_key(rows, "role", "engagement_score"),
      "distribution" => engagement_histogram(eng),
      "headcount_by_date" => headcount_trend(rows, "survey_date")
    }
  end

  def turnover_section
    rows = rows_for_type("turnover")
    return { "rate" => nil, "exits" => 0 } if rows.empty?

    tenures = numeric_values(rows, "tenure_months")
    reasons = rows.map { |r| r.data["reason"] }.compact.tally
    by_role = rows.map { |r| r.data["role"] }.compact.tally

    {
      "exits" => rows.size,
      "average_tenure_months" => mean(tenures),
      "rate" => calculate_turnover_rate(rows),
      "by_reason" => reasons,
      "by_role" => by_role,
      "by_month" => count_by_month(rows, "exit_date"),
      "tenure_distribution" => tenure_histogram(tenures)
    }
  end

  def events_section
    rows = rows_for_type("events")
    return { "attendance_rate" => nil, "by_format" => {} } if rows.empty?

    rates = numeric_values(rows, "attendance_rate")
    by_format = rows.group_by { |r| r.data["format"] }
                    .reject { |k, _| k.blank? }
                    .transform_values { |grp| mean(numeric_values(grp, "attendance_rate")) }
                    .compact

    top_events = rows.map do |r|
      rate = Float(r.data["attendance_rate"]) rescue nil
      [r.data["event_name"], rate]
    end.reject { |_, v| v.nil? }
       .sort_by { |_, v| -v }
       .first(8)
       .map { |name, v| { "name" => name, "rate" => v } }

    {
      "events" => rows.size,
      "attendance_rate" => mean(rates),
      "by_format" => by_format,
      "by_date" => trend_by_month(rows, "event_date", "attendance_rate"),
      "top_events" => top_events
    }
  end

  def communications_section
    rows = rows_for_type("feedback")
    return {} if rows.empty?

    {
      "preferred_channel" => mode(rows.map { |r| r.data["preferred_channel"] }),
      "preferred_frequency" => mode(rows.map { |r| r.data["update_frequency"] }),
      "channel_distribution" => rows.map { |r| r.data["preferred_channel"] }.compact.reject(&:empty?).tally,
      "frequency_distribution" => rows.map { |r| r.data["update_frequency"] }.compact.reject(&:empty?).tally
    }
  end

  def feedback_section
    rows = rows_for_type("feedback")
    return {} if rows.empty?

    feedback = rows.map { |r| r.data["feedback"].to_s }.reject(&:empty?)
    return {} if feedback.empty?

    summary = TextAnalyticsService.summarize(feedback)
    summary.merge(
      "sentiment_by_date" => sentiment_trend(rows)
    )
  end

  def sentiment_trend(rows)
    by_month = rows.group_by { |r| r.data["submitted_at"].to_s[0, 7] }
                   .reject { |k, _| k.blank? }
                   .sort.to_h
    by_month.transform_values do |grp|
      texts = grp.map { |r| r.data["feedback"].to_s }.reject(&:empty?)
      next 0.0 if texts.empty?

      scores = texts.map do |t|
        case TextAnalyticsService.score(t)
        when "positive" then 1
        when "negative" then -1
        else 0
        end
      end
      (scores.sum.to_f / scores.size).round(3)
    end
  end

  def avg_by_key(rows, key, value_key)
    rows.group_by { |r| r.data[key] }
        .reject { |k, _| k.blank? }
        .transform_values { |grp| mean(numeric_values(grp, value_key)) }
        .compact
        .sort_by { |_, v| -v.to_f }
        .to_h
  end

  def engagement_histogram(values)
    return [] if values.empty?

    buckets = [
      ["1.0-1.9", 1.0, 1.99],
      ["2.0-2.4", 2.0, 2.49],
      ["2.5-2.9", 2.5, 2.99],
      ["3.0-3.4", 3.0, 3.49],
      ["3.5-3.9", 3.5, 3.99],
      ["4.0-4.4", 4.0, 4.49],
      ["4.5-5.0", 4.5, 5.0]
    ]
    buckets.map do |label, lo, hi|
      count = values.count { |v| v >= lo && v <= hi }
      { "range" => label, "count" => count }
    end
  end

  def tenure_histogram(values)
    return [] if values.empty?

    buckets = [
      ["0-6 mo", 0, 5],
      ["6-12 mo", 6, 11],
      ["1-2 yr", 12, 23],
      ["2-3 yr", 24, 35],
      ["3-5 yr", 36, 59],
      ["5+ yr", 60, 1_000]
    ]
    buckets.map do |label, lo, hi|
      count = values.count { |v| v >= lo && v <= hi }
      { "range" => label, "count" => count }
    end
  end

  def count_by_month(rows, date_key)
    rows.group_by { |r| r.data[date_key].to_s[0, 7] }
        .reject { |k, _| k.blank? }
        .transform_values(&:size)
        .sort.to_h
  end

  def headcount_trend(rows, date_key)
    rows.group_by { |r| r.data[date_key].to_s[0, 7] }
        .reject { |k, _| k.blank? }
        .transform_values { |grp| grp.map { |r| r.data["employee_id"] }.compact.uniq.size }
        .sort.to_h
  end

  def numeric_values(rows, key)
    rows.map { |r| Float(r.data[key]) rescue nil }.compact
  end

  def mean(values)
    return nil if values.empty?

    (values.sum.to_f / values.size).round(3)
  end

  def mode(values)
    cleaned = Array(values).compact.reject { |v| v.to_s.strip.empty? }
    return nil if cleaned.empty?

    cleaned.tally.max_by { |_, c| c }.first
  end

  def calculate_turnover_rate(exit_rows)
    eng_rows = rows_for_type("engagement")
    base = eng_rows.map { |r| r.data["employee_id"] }.compact.uniq.size
    return nil if base.zero? && exit_rows.empty?

    (exit_rows.size.to_f / (base + exit_rows.size)).round(3)
  end

  def trend_by_month(rows, date_key, value_key)
    rows.group_by { |r| r.data[date_key].to_s[0, 7] }
        .reject { |k, _| k.blank? }
        .transform_values { |grp| mean(numeric_values(grp, value_key)) }
        .sort.to_h
  end
end
