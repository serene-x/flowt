require "prawn"
require "prawn/table"

class FullReportExporter
  PRIMARY = "4F46E5".freeze
  PRIMARY_LIGHT = "C7D2FE".freeze
  STONE_DARK = "1C1917".freeze
  STONE_MID = "57534E".freeze
  STONE_LIGHT = "A8A29E".freeze
  STONE_BG = "F5F5F4".freeze
  CRITICAL = "BE123C".freeze
  WARNING = "B45309".freeze
  POSITIVE = "047857".freeze

  def self.call(department)
    new(department).call
  end

  def initialize(department)
    @department = department
    @snapshot = department.department_profile&.snapshot_data || {}
    @insights = InsightEngineService.call(department)
    @recommendations = RecommendationsService.call(department, insight_cards: @insights)
    @summary = AiSummaryService.call(department) rescue nil
  end

  def call
    Prawn::Document.new(page_size: "LETTER", margin: [70, 56, 56, 56]) do |pdf|
      @pdf = pdf
      register_unicode_font
      pdf.font "Body"

      render_executive_summary
      pdf.start_new_page
      render_key_metrics
      pdf.start_new_page
      render_charts
      pdf.start_new_page
      render_communications

      apply_header_to_all_pages
    end.render
  end

  private

  attr_reader :department, :snapshot, :insights, :recommendations, :summary

  def register_unicode_font
    candidates = [
      "/System/Library/Fonts/Helvetica.ttc",
      "/System/Library/Fonts/Supplemental/Arial.ttf",
      "/Library/Fonts/Arial.ttf",
      "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    ]
    found = candidates.find { |path| File.exist?(path) }

    if found && found.end_with?(".ttc")
      @pdf.font_families.update("Body" => {
        normal: { file: found, font: "Helvetica" },
        bold: { file: found, font: "Helvetica-Bold" },
        italic: { file: found, font: "Helvetica-Oblique" }
      })
    elsif found
      @pdf.font_families.update("Body" => { normal: found, bold: found, italic: found })
    else
      @pdf.font_families.update("Body" => { normal: "Helvetica", bold: "Helvetica-Bold", italic: "Helvetica-Oblique" })
    end
  rescue StandardError
    @pdf.font_families.update("Body" => { normal: "Helvetica", bold: "Helvetica-Bold", italic: "Helvetica-Oblique" })
  end

  def render_executive_summary
    title("Executive Summary")
    @pdf.text @department.name, size: 18, style: :bold, color: STONE_DARK
    @pdf.text "Generated #{Time.current.strftime('%B %-d, %Y')} • Flowt", size: 9, color: STONE_LIGHT
    @pdf.move_down 18

    headline_metric_strip
    @pdf.move_down 18

    if @summary
      @pdf.fill_color PRIMARY_LIGHT
      bg_y = @pdf.cursor
      @pdf.move_down 4
      @pdf.text "EXECUTIVE BRIEF", size: 8, style: :bold, color: PRIMARY
      @pdf.move_down 4
      @pdf.text @summary.summary_text.to_s, size: 10, leading: 4, color: STONE_DARK
      @pdf.move_down 12
      @pdf.fill_color STONE_DARK
    end

    if @insights.any?
      @pdf.text "Key Insights", size: 12, style: :bold, color: STONE_DARK
      @pdf.move_down 8
      @insights.each do |card|
        color = severity_color(card.severity)
        prefix = severity_prefix(card.severity)
        @pdf.formatted_text [
          { text: "#{prefix}  ", color: color, styles: [:bold] },
          { text: card.finding.to_s, color: STONE_DARK, styles: [:bold] }
        ], size: 10
        @pdf.indent(20) do
          @pdf.text card.stat.to_s, size: 9, color: STONE_MID
        end
        @pdf.move_down 7
      end
      @pdf.move_down 8
    end

    if @recommendations.any?
      @pdf.text "Top Recommended Actions", size: 12, style: :bold, color: STONE_DARK
      @pdf.move_down 8
      @recommendations.first(3).each_with_index do |rec, idx|
        @pdf.formatted_text [
          { text: "#{idx + 1}.  ", color: STONE_LIGHT, styles: [:bold] },
          { text: rec.priority.to_s.upcase, color: priority_color(rec.priority), styles: [:bold] },
          { text: "  " + rec.action.to_s, color: STONE_DARK, styles: [:bold] }
        ], size: 10
        @pdf.indent(20) do
          @pdf.text rec.rationale.to_s, size: 9, color: STONE_MID
        end
        @pdf.move_down 7
      end
    end
  end

  def headline_metric_strip
    metrics = [
      ["Headcount", @snapshot.dig("headcount", "total")&.to_s || "—"],
      ["Engagement", @snapshot.dig("engagement", "average")&.round(2)&.to_s || "—"],
      ["Turnover", percent(@snapshot.dig("turnover", "rate"))],
      ["Attendance", percent(@snapshot.dig("events", "attendance_rate"))]
    ]
    column_w = (@pdf.bounds.width - 30) / 4.0
    start_y = @pdf.cursor

    metrics.each_with_index do |(label, value), idx|
      x = idx * (column_w + 10)
      @pdf.bounding_box([x, start_y], width: column_w, height: 56) do
        @pdf.fill_color STONE_BG
        @pdf.fill_rectangle [0, 56], column_w, 56
        @pdf.fill_color STONE_LIGHT
        @pdf.draw_text label.upcase, at: [10, 36], size: 8
        @pdf.fill_color STONE_DARK
        @pdf.draw_text value, at: [10, 14], size: 18, style: :bold
      end
    end
    @pdf.move_down 60
  end

  def render_key_metrics
    title("Key Metrics")

    rows = [
      ["Metric", "Value", "Band", "Detail"],
      ["Headcount", display(@snapshot.dig("headcount", "total")), "—", "From engagement responses"],
      ["Turnover rate", percent(@snapshot.dig("turnover", "rate")),
       band_label(ThresholdService.turnover_band(@snapshot.dig("turnover", "rate"))),
       "#{@snapshot.dig('turnover', 'exits') || 0} exits"],
      ["Avg engagement", display(@snapshot.dig("engagement", "average")&.round(2)),
       band_label(ThresholdService.engagement_band(@snapshot.dig("engagement", "average"))),
       "#{@snapshot.dig('engagement', 'sample_size') || 0} responses"],
      ["Avg satisfaction", display(@snapshot.dig("engagement", "satisfaction_average")&.round(2)),
       "—", "Self-reported"],
      ["Event attendance", percent(@snapshot.dig("events", "attendance_rate")),
       band_label(ThresholdService.attendance_band(@snapshot.dig("events", "attendance_rate"))),
       "#{@snapshot.dig('events', 'events') || 0} events tracked"],
      ["Avg tenure (mo)", display(@snapshot.dig("turnover", "average_tenure_months")&.round(1)),
       "—", "From exit records"],
      ["Sentiment",
       sentiment_summary,
       band_label(ThresholdService.sentiment_band(@snapshot.dig("feedback", "sentiment_breakdown") || {})),
       "From free-text feedback"]
    ].map { |row| row.map { |c| sanitize(c) } }

    @pdf.table(rows, header: true, width: @pdf.bounds.width,
               cell_style: { padding: 9, border_width: 0.5, border_color: "E7E5E4", size: 10 }) do
      row(0).font_style = :bold
      row(0).background_color = STONE_BG
      row(0).text_color = STONE_MID
    end
  end

  def render_charts
    title("Trends & Distributions")

    by_date = @snapshot.dig("engagement", "by_date") || {}
    if by_date.any?
      section_label("Engagement over time")
      draw_line_chart(by_date, max: 5.0, height: 130)
      @pdf.move_down 18
    end

    by_reason = @snapshot.dig("turnover", "by_reason") || {}
    if by_reason.any?
      section_label("Exit reasons")
      draw_horizontal_bars(by_reason.sort_by { |_, v| -v }.to_h, height_per_row: 22)
      @pdf.move_down 18
    end

    by_format = @snapshot.dig("events", "by_format") || {}
    if by_format.any?
      section_label("Attendance by event format")
      pct_data = by_format.transform_values { |v| (v.to_f * 100).round(1) }
      draw_horizontal_bars(pct_data, suffix: "%", max: 100, height_per_row: 22)
      @pdf.move_down 18
    end

    breakdown = @snapshot.dig("feedback", "sentiment_breakdown") || {}
    if breakdown.values.map(&:to_i).sum.positive?
      section_label("Sentiment breakdown")
      ordered = { "Positive" => breakdown["positive"].to_i, "Neutral" => breakdown["neutral"].to_i, "Negative" => breakdown["negative"].to_i }
      colors = { "Positive" => POSITIVE, "Neutral" => STONE_LIGHT, "Negative" => CRITICAL }
      draw_horizontal_bars(ordered, height_per_row: 22, color_map: colors)
    end
  end

  def render_communications
    title("Communications Profile")

    comms = @snapshot["communications"] || {}

    pref_w = (@pdf.bounds.width - 12) / 2.0
    start_y = @pdf.cursor
    [["Preferred Channel", comms["preferred_channel"]],
     ["Preferred Frequency", comms["preferred_frequency"]]].each_with_index do |(label, value), idx|
      x = idx * (pref_w + 12)
      @pdf.bounding_box([x, start_y], width: pref_w, height: 64) do
        @pdf.stroke_color "E5E7EB"
        @pdf.stroke_bounds
        @pdf.fill_color STONE_LIGHT
        @pdf.draw_text label.upcase, at: [12, 42], size: 8
        @pdf.fill_color PRIMARY
        @pdf.draw_text sanitize(value || "Unknown"), at: [12, 16], size: 16, style: :bold
      end
    end
    @pdf.fill_color STONE_DARK
    @pdf.move_down 80

    if (dist = comms["channel_distribution"]).is_a?(Hash) && dist.any?
      section_label("Channel distribution")
      draw_horizontal_bars(dist.sort_by { |_, v| -v }.to_h, height_per_row: 22)
      @pdf.move_down 14
    end

    if (dist = comms["frequency_distribution"]).is_a?(Hash) && dist.any?
      section_label("Update frequency")
      draw_horizontal_bars(dist.sort_by { |_, v| -v }.to_h, height_per_row: 22)
      @pdf.move_down 14
    end

    comms_recs = @recommendations.select { |r| r.action.to_s.match?(/communicat|channel|async/i) }
    if comms_recs.any?
      section_label("Communications recommendations")
      comms_recs.each do |rec|
        @pdf.formatted_text [
          { text: rec.priority.to_s.upcase, color: priority_color(rec.priority), styles: [:bold] },
          { text: "  " + sanitize(rec.action), color: STONE_DARK }
        ], size: 10
        @pdf.indent(10) { @pdf.text sanitize(rec.rationale), size: 9, color: STONE_MID }
        @pdf.move_down 7
      end
    end
  end

  def section_label(text)
    @pdf.text sanitize(text), size: 11, style: :bold, color: STONE_DARK
    @pdf.move_down 8
  end

  def draw_horizontal_bars(data, max: nil, suffix: "", height_per_row: 22, color_map: nil)
    return if data.empty?

    label_width = 110
    chart_width = @pdf.bounds.width - label_width - 60
    chart_max = max || data.values.map(&:to_f).max
    chart_max = 1.0 if chart_max.zero?

    start_y = @pdf.cursor
    data.each_with_index do |(label, value), idx|
      y = start_y - idx * height_per_row
      @pdf.fill_color STONE_DARK
      @pdf.draw_text sanitize(label.to_s), at: [0, y - 14], size: 9
      bar_width = (value.to_f / chart_max) * chart_width
      bar_color = (color_map && color_map[label]) || PRIMARY
      @pdf.fill_color bar_color
      @pdf.fill_rectangle [label_width, y - 6], [bar_width, 1].max, 12
      @pdf.fill_color STONE_MID
      @pdf.draw_text "#{format_number(value)}#{suffix}", at: [label_width + bar_width + 6, y - 14], size: 9
    end
    @pdf.fill_color STONE_DARK
    @pdf.move_down(data.size * height_per_row + 4)
  end

  def draw_line_chart(by_date, max:, height:)
    points = by_date.map { |k, v| [k, v.to_f] }
    return if points.empty?

    chart_width = @pdf.bounds.width
    start_y = @pdf.cursor

    @pdf.bounding_box([0, start_y], width: chart_width, height: height + 30) do
      plot_x = 40
      plot_w = chart_width - plot_x - 10
      plot_h = height
      plot_y_bottom = 30

      @pdf.stroke_color "E7E5E4"
      @pdf.line_width 0.5
      4.times do |i|
        y = plot_y_bottom + (plot_h * i / 4.0)
        @pdf.stroke_horizontal_line plot_x, plot_x + plot_w, at: y
        @pdf.fill_color STONE_LIGHT
        @pdf.draw_text((max * (i / 4.0)).round(1).to_s, at: [4, y - 3], size: 7)
      end

      coords = points.each_with_index.map do |(_, v), idx|
        x = plot_x + (idx.to_f / [points.size - 1, 1].max) * plot_w
        y = plot_y_bottom + (v / max) * plot_h
        [x, y]
      end

      # Filled area under line
      @pdf.fill_color PRIMARY_LIGHT
      poly = [[coords.first[0], plot_y_bottom]] + coords + [[coords.last[0], plot_y_bottom]]
      @pdf.fill_polygon(*poly)

      # Line
      @pdf.stroke_color PRIMARY
      @pdf.line_width 1.5
      coords.each_cons(2) do |a, b|
        @pdf.stroke_line a, b
      end

      # Points
      @pdf.fill_color PRIMARY
      coords.each { |x, y| @pdf.fill_circle [x, y], 2.5 }

      # X-axis labels
      @pdf.fill_color STONE_MID
      points.each_with_index do |(label, _), idx|
        next if points.size > 8 && idx.odd?

        x = plot_x + (idx.to_f / [points.size - 1, 1].max) * plot_w
        text_w = @pdf.width_of(label, size: 7)
        @pdf.draw_text label, at: [x - text_w / 2.0, 14], size: 7
      end
    end

    @pdf.move_down(height + 30)
  end

  def apply_header_to_all_pages
    @pdf.repeat(:all) do
      @pdf.canvas do
        @pdf.fill_color PRIMARY
        @pdf.fill_rectangle [0, @pdf.bounds.top], @pdf.bounds.width, 4
        @pdf.fill_color STONE_LIGHT
        @pdf.draw_text "Flowt",
                       at: [56, @pdf.bounds.top - 24], size: 9, style: :bold
        right_text = sanitize(@department.name)
        right_w = @pdf.width_of(right_text, size: 9, style: :bold)
        @pdf.draw_text right_text,
                       at: [@pdf.bounds.width - 56 - right_w, @pdf.bounds.top - 24],
                       size: 9, style: :bold
      end
      @pdf.fill_color STONE_DARK
    end
    @pdf.number_pages "Page <page> of <total>",
                      at: [0, 14],
                      width: @pdf.bounds.width,
                      align: :center,
                      size: 8,
                      color: STONE_LIGHT
  end

  def title(text)
    @pdf.text sanitize(text), size: 22, style: :bold, color: STONE_DARK
    @pdf.fill_color PRIMARY
    @pdf.fill_rectangle [0, @pdf.cursor + 4], 36, 2
    @pdf.fill_color STONE_DARK
    @pdf.move_down 16
  end

  def severity_color(severity)
    case severity
    when :critical then CRITICAL
    when :warning then WARNING
    when :positive then POSITIVE
    else STONE_MID
    end
  end

  def severity_prefix(severity)
    case severity
    when :critical then "[!]"
    when :warning then "[~]"
    when :positive then "[+]"
    else "•"
    end
  end

  def priority_color(priority)
    case priority
    when :high then CRITICAL
    when :medium then WARNING
    when :low then POSITIVE
    else STONE_MID
    end
  end

  def band_label(band)
    case band
    when :critical then "Critical"
    when :warning then "Warning"
    when :healthy then "Healthy"
    else "—"
    end
  end

  def display(value)
    value.nil? ? "—" : sanitize(value.to_s)
  end

  def percent(value)
    value.nil? ? "—" : "#{(value * 100).round(1)}%"
  end

  def format_number(value)
    if value.is_a?(Float)
      value == value.to_i ? value.to_i.to_s : value.round(1).to_s
    else
      value.to_s
    end
  end

  def sentiment_summary
    breakdown = @snapshot.dig("feedback", "sentiment_breakdown") || {}
    total = breakdown.values.map(&:to_i).sum
    return "—" if total.zero?

    pos = breakdown["positive"].to_i * 100 / total
    neg = breakdown["negative"].to_i * 100 / total
    "#{pos}% pos / #{neg}% neg"
  end

  def sanitize(text)
    text.to_s
        .gsub(/[‘’]/, "'")
        .gsub(/[“”]/, '"')
  end
end
