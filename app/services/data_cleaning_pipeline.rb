class DataCleaningPipeline
  Result = Struct.new(:rows, :diff, keyword_init: true)

  def self.call(rows, columns)
    new(rows, columns).call
  end

  def initialize(rows, columns)
    @rows = rows.map(&:dup)
    @columns = columns
  end

  def call
    diff = []
    diff << drop_empty_rows
    diff << trim_whitespace
    diff << normalize_dates
    diff << standardize_categoricals
    diff << flag_outliers
    diff << flag_duplicates
    Result.new(rows: @rows, diff: diff.compact)
  end

  private

  attr_reader :columns

  def drop_empty_rows
    before = @rows.size
    @rows = @rows.reject { |row| row.values.all? { |v| v.to_s.strip.empty? } }
    removed = before - @rows.size
    return nil if removed.zero?

    { change: "drop_empty_rows", count: removed, description: "Removed #{removed} fully empty row(s)" }
  end

  def trim_whitespace
    count = 0
    @rows.each do |row|
      row.each do |key, value|
        next unless value.is_a?(String)

        trimmed = value.gsub(/\s+/, " ").strip
        if trimmed != value
          row[key] = trimmed
          count += 1
        end
      end
    end
    return nil if count.zero?

    { change: "trim_whitespace", count: count, description: "Trimmed whitespace in #{count} field(s)" }
  end

  def normalize_dates
    date_columns = columns.select { |c| c[:data_type] == "date" }.map { |c| c[:name] }
    return nil if date_columns.empty?

    count = 0
    @rows.each do |row|
      date_columns.each do |key|
        raw = row[key]
        next if raw.nil? || raw.to_s.strip.empty?

        iso = parse_to_iso(raw)
        if iso && iso != raw
          row[key] = iso
          count += 1
        end
      end
    end
    return nil if count.zero?

    { change: "normalize_dates", count: count, description: "Normalized #{count} date value(s) to ISO 8601" }
  end

  def parse_to_iso(value)
    parsed = CsvParserService.parse_date(value.to_s)
    parsed&.iso8601
  end

  def standardize_categoricals
    cat_columns = columns.select { |c| c[:data_type] == "categorical" }.map { |c| c[:name] }
    return nil if cat_columns.empty?

    count = 0
    cat_columns.each do |key|
      values = @rows.map { |r| r[key] }.compact.map { |v| v.to_s.strip }.reject(&:empty?)
      canonical = build_canonical_map(values)

      @rows.each do |row|
        raw = row[key]
        next if raw.nil? || raw.to_s.strip.empty?

        normalized = canonical[raw.to_s.strip.downcase] || raw
        if normalized != raw
          row[key] = normalized
          count += 1
        end
      end
    end

    return nil if count.zero?

    { change: "standardize_categoricals", count: count, description: "Normalized #{count} categorical value(s)" }
  end

  def build_canonical_map(values)
    grouped = values.group_by { |v| v.downcase }
    grouped.transform_values do |variants|
      variants.tally.max_by { |_, c| c }.first
    end
  end

  def flag_outliers
    numeric_columns = columns.select { |c| c[:data_type] == "numeric" }.map { |c| c[:name] }
    return nil if numeric_columns.empty?

    flagged = 0
    numeric_columns.each do |key|
      numbers = @rows.map { |r| Float(r[key]) rescue nil }.compact
      next if numbers.size < 4

      lower, upper = iqr_bounds(numbers)
      @rows.each do |row|
        value = Float(row[key]) rescue nil
        next if value.nil?

        if value < lower || value > upper
          row["__flags__"] ||= []
          row["__flags__"] << { kind: "outlier", column: key, value: value }
          flagged += 1
        end
      end
    end

    return nil if flagged.zero?

    { change: "flag_outliers", count: flagged, description: "Flagged #{flagged} numeric outlier(s) using IQR" }
  end

  def iqr_bounds(numbers)
    sorted = numbers.sort
    q1 = percentile(sorted, 0.25)
    q3 = percentile(sorted, 0.75)
    iqr = q3 - q1
    [q1 - 1.5 * iqr, q3 + 1.5 * iqr]
  end

  def percentile(sorted, p)
    return sorted.first if sorted.size == 1

    rank = p * (sorted.size - 1)
    low = sorted[rank.floor]
    high = sorted[rank.ceil]
    low + (high - low) * (rank - rank.floor)
  end

  def flag_duplicates
    id_key = columns.map { |c| c[:name] }.find { |n| n.downcase.include?("employee_id") || n.downcase == "id" }
    return nil unless id_key

    seen = Hash.new(0)
    @rows.each { |r| seen[r[id_key].to_s.strip] += 1 if r[id_key].to_s.strip.length.positive? }
    duplicates = seen.select { |_, c| c > 1 }.keys
    return nil if duplicates.empty?

    flagged = 0
    @rows.each do |row|
      next unless duplicates.include?(row[id_key].to_s.strip)

      row["__flags__"] ||= []
      row["__flags__"] << { kind: "duplicate_id", column: id_key, value: row[id_key] }
      flagged += 1
    end

    { change: "flag_duplicates", count: flagged, description: "Flagged #{flagged} row(s) with duplicate #{id_key}" }
  end
end
