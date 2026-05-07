require "csv"

class CsvParserService
  Result = Struct.new(:headers, :columns, :rows, :preview, :total_rows, :warnings, keyword_init: true)

  TYPE_THRESHOLD = 0.8
  CATEGORICAL_RATIO = 0.5
  DATE_FORMATS = [
    "%Y-%m-%d",
    "%Y/%m/%d",
    "%m/%d/%Y",
    "%d/%m/%Y",
    "%m-%d-%Y",
    "%d-%m-%Y",
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%d %H:%M:%S"
  ].freeze

  def self.call(io)
    new(io).call
  end

  def initialize(io)
    @io = io
  end

  def call
    rows = read_rows
    headers = rows.shift || []
    headers = headers.map { |h| (h || "").to_s.strip }

    if headers.empty? || rows.empty?
      return Result.new(headers: headers, columns: [], rows: [], preview: [], total_rows: 0, warnings: [empty_warning])
    end

    rows = rows.map { |r| pad_row(r, headers.size) }
    columns = build_columns(headers, rows)
    preview = rows.first(10).map { |r| row_to_hash(headers, r) }
    warnings = collect_warnings(headers, rows, columns)
    full_rows = rows.map { |r| row_to_hash(headers, r) }

    Result.new(
      headers: headers,
      columns: columns,
      rows: full_rows,
      preview: preview,
      total_rows: full_rows.size,
      warnings: warnings
    )
  end

  private

  attr_reader :io

  def read_rows
    text = io.respond_to?(:read) ? io.read : io.to_s
    text = text.to_s.dup.force_encoding("UTF-8").scrub
    CSV.parse(text, liberal_parsing: true)
  rescue CSV::MalformedCSVError => e
    raise CsvParserService::Error, "Could not parse CSV: #{e.message}"
  end

  def pad_row(row, size)
    row = Array(row)
    if row.size < size
      row + Array.new(size - row.size)
    else
      row.first(size)
    end
  end

  def row_to_hash(headers, row)
    headers.zip(row).to_h
  end

  def build_columns(headers, rows)
    headers.each_with_index.map do |name, idx|
      values = rows.map { |r| r[idx] }
      {
        name: name,
        position: idx,
        data_type: detect_type(values),
        sample_values: values.compact.reject { |v| v.to_s.strip.empty? }.first(5)
      }
    end
  end

  def detect_type(values)
    cleaned = values.compact.map { |v| v.to_s.strip }.reject(&:empty?)
    return "text" if cleaned.empty?

    counts = {
      "numeric" => cleaned.count { |v| numeric?(v) },
      "date" => cleaned.count { |v| date?(v) }
    }
    total = cleaned.size.to_f

    if counts["numeric"] / total >= TYPE_THRESHOLD
      "numeric"
    elsif counts["date"] / total >= TYPE_THRESHOLD
      "date"
    elsif (cleaned.uniq.size.to_f / total) <= CATEGORICAL_RATIO
      "categorical"
    else
      "text"
    end
  end

  def numeric?(value)
    Float(value)
    true
  rescue ArgumentError, TypeError
    false
  end

  def date?(value)
    return false if value.match?(/\A-?\d+(\.\d+)?\z/)

    !!self.class.parse_date(value)
  end

  def self.parse_date(value)
    DATE_FORMATS.each do |fmt|
      parsed = Date.strptime(value, fmt) rescue nil
      next unless parsed
      next unless parsed.strftime(fmt) == value

      return parsed
    end
    nil
  end

  def collect_warnings(headers, rows, columns)
    warnings = []

    blank_headers = headers.each_with_index.select { |h, _| h.empty? }.map { |_, i| i }
    if blank_headers.any?
      warnings << { kind: "blank_header", message: "Columns at positions #{blank_headers.join(', ')} have no header" }
    end

    columns.each_with_index do |col, idx|
      missing = rows.count { |r| r[idx].to_s.strip.empty? }
      if missing.positive?
        warnings << { kind: "missing_values", column: col[:name], count: missing }
      end
    end

    id_col = headers.find_index { |h| h.downcase.include?("employee_id") || h.downcase == "id" }
    if id_col
      ids = rows.map { |r| r[id_col].to_s.strip }.reject(&:empty?)
      duplicates = ids.tally.select { |_, c| c > 1 }.keys
      if duplicates.any?
        warnings << { kind: "duplicate_ids", column: headers[id_col], values: duplicates.first(20), count: duplicates.size }
      end
    end

    warnings
  end

  def empty_warning
    { kind: "empty_file", message: "CSV had no usable rows" }
  end

  class Error < StandardError; end
end
