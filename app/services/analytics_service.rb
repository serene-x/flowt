class AnalyticsService
  HISTOGRAM_BUCKETS = 10
  TOP_N = 10

  def self.column_stats(dataset_column, rows)
    new(dataset_column, rows).column_stats
  end

  def self.dataset_summary(dataset)
    summary = {
      row_count: dataset.row_count,
      column_count: dataset.dataset_columns.size,
      flag_count: dataset.data_rows.where("flags @> '{\"flagged\": true}'").count
    }
    summary
  end

  def self.global_metrics
    {
      department_count: Department.count,
      dataset_count: Dataset.count,
      row_count: DataRow.count,
      ready_count: Dataset.status_ready.count,
      pending_count: Dataset.where(status: [:pending, :processing]).count
    }
  end

  def self.department_comparison
    Department.includes(:datasets, department_profile: []).map do |department|
      profile = department.department_profile&.snapshot_data || {}
      {
        id: department.id,
        slug: department.slug,
        name: department.name,
        dataset_count: department.relevant_datasets.count,
        engagement: profile.dig("engagement", "average"),
        satisfaction: profile.dig("engagement", "satisfaction_average"),
        turnover_rate: profile.dig("turnover", "rate"),
        attendance_rate: profile.dig("events", "attendance_rate"),
        headcount: profile.dig("headcount", "total")
      }
    end
  end

  def initialize(dataset_column, rows)
    @column = dataset_column
    @raw_values = rows.map { |r| r.data[dataset_column.name] }
  end

  def column_stats
    case @column.data_type
    when "numeric" then numeric_stats
    when "categorical" then categorical_stats
    when "date" then date_stats
    else text_stats
    end
  end

  private

  def numeric_stats
    numbers = @raw_values.map { |v| Float(v) rescue nil }
    nulls = numbers.count(&:nil?)
    valid = numbers.compact.sort

    base = {
      type: "numeric",
      count: numbers.size,
      null_count: nulls,
      unique_count: valid.uniq.size
    }

    return base.merge(min: nil, max: nil, mean: nil, median: nil, histogram: []) if valid.empty?

    base.merge(
      min: valid.first,
      max: valid.last,
      mean: (valid.sum / valid.size.to_f).round(3),
      median: median(valid).round(3),
      histogram: histogram(valid)
    )
  end

  def categorical_stats
    cleaned = @raw_values.map { |v| v.to_s.strip }.reject(&:empty?)
    nulls = @raw_values.size - cleaned.size
    counts = cleaned.tally.sort_by { |_, c| -c }.first(TOP_N)

    {
      type: "categorical",
      count: @raw_values.size,
      null_count: nulls,
      unique_count: cleaned.uniq.size,
      top_values: counts.map { |label, count| { label: label, count: count } }
    }
  end

  def date_stats
    dates = @raw_values.map { |v| Date.parse(v.to_s) rescue nil }
    valid = dates.compact.sort
    by_month = valid.group_by { |d| d.strftime("%Y-%m") }.transform_values(&:size).sort.to_h

    {
      type: "date",
      count: @raw_values.size,
      null_count: dates.count(&:nil?),
      unique_count: valid.uniq.size,
      min: valid.first&.iso8601,
      max: valid.last&.iso8601,
      by_month: by_month
    }
  end

  def text_stats
    cleaned = @raw_values.map { |v| v.to_s.strip }.reject(&:empty?)
    word_counts = cleaned.map { |t| t.split(/\s+/).size }

    {
      type: "text",
      count: @raw_values.size,
      null_count: @raw_values.size - cleaned.size,
      unique_count: cleaned.uniq.size,
      avg_word_count: word_counts.empty? ? 0 : (word_counts.sum.to_f / word_counts.size).round(1),
      max_word_count: word_counts.max || 0
    }
  end

  def median(sorted)
    n = sorted.size
    return sorted.first.to_f if n == 1

    mid = n / 2
    n.odd? ? sorted[mid].to_f : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def histogram(values)
    return [] if values.empty?

    min, max = values.minmax
    return [{ range: "#{min}-#{max}", count: values.size }] if min == max

    buckets = HISTOGRAM_BUCKETS
    width = (max - min) / buckets.to_f
    counts = Array.new(buckets, 0)
    values.each do |v|
      idx = ((v - min) / width).floor
      idx = buckets - 1 if idx >= buckets
      counts[idx] += 1
    end
    counts.each_with_index.map do |count, i|
      lower = (min + i * width).round(2)
      upper = (min + (i + 1) * width).round(2)
      { range: "#{lower}–#{upper}", count: count }
    end
  end
end
