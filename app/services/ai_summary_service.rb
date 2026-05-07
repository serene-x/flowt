require "net/http"
require "json"
require "digest"

class AiSummaryService
  Result = Struct.new(:summary_text, :source, :fingerprint, :cached, keyword_init: true)

  MODEL = "claude-sonnet-4-6".freeze
  API_URL = "https://api.anthropic.com/v1/messages".freeze
  MAX_TOKENS = 400
  TIMEOUT_SECONDS = 20

  def self.call(department, force: false)
    new(department, force: force).call
  end

  def initialize(department, force: false)
    @department = department
    @force = force
  end

  def call
    fingerprint = compute_fingerprint
    cached = AiSummary.find_by(department_id: @department.id)

    if cached && cached.data_fingerprint == fingerprint && !@force
      return Result.new(summary_text: cached.summary_text, source: cached.source,
                        fingerprint: fingerprint, cached: true)
    end

    text, source = generate(fingerprint)
    record = cached || AiSummary.new(department: @department)
    record.assign_attributes(
      summary_text: text,
      source: source,
      generated_at: Time.current,
      data_fingerprint: fingerprint
    )
    record.save!

    Result.new(summary_text: text, source: source, fingerprint: fingerprint, cached: false)
  end

  def self.fingerprint_for(department)
    new(department).send(:compute_fingerprint)
  end

  private

  def generate(fingerprint)
    prompt = build_prompt
    api_key = ENV["ANTHROPIC_API_KEY"]

    if api_key.to_s.strip.empty?
      return [fallback_summary, "fallback"]
    end

    response = call_claude(prompt, api_key)
    [response, "claude"]
  rescue StandardError => e
    Rails.logger.warn("AiSummaryService Claude call failed: #{e.class}: #{e.message}")
    [fallback_summary, "fallback"]
  end

  def call_claude(prompt, api_key)
    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["x-api-key"] = api_key
    request["anthropic-version"] = "2023-06-01"
    request["content-type"] = "application/json"
    request.body = {
      model: MODEL,
      max_tokens: MAX_TOKENS,
      messages: [{ role: "user", content: prompt }]
    }.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                    open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
      response = http.request(request)
      raise "Claude API #{response.code}: #{response.body}" unless response.code.to_i.between?(200, 299)

      data = JSON.parse(response.body)
      content = data.dig("content", 0, "text")
      raise "Empty response" if content.to_s.strip.empty?

      content.strip
    end
  end

  def build_prompt
    snapshot = @department.department_profile&.snapshot_data || {}
    headcount = snapshot.dig("headcount", "total")
    turnover_rate = snapshot.dig("turnover", "rate")
    engagement = snapshot.dig("engagement", "average")
    by_date = snapshot.dig("engagement", "by_date") || {}
    eng_values = by_date.values.compact
    trend_direction = if eng_values.size >= 2
      diff = eng_values.last - eng_values[-2]
      diff > 0.05 ? "rising" : diff < -0.05 ? "falling" : "flat"
    else
      "n/a"
    end

    attendance = snapshot.dig("events", "attendance_rate")
    themes = (snapshot.dig("feedback", "themes") || []).first(3).map { |t| t["term"] }
    pref_channel = snapshot.dig("communications", "preferred_channel")

    cards = InsightEngineService.call(@department).select { |c| %i[critical warning].include?(c.severity) }
    cards_text = cards.map { |c| "- #{c.severity.upcase}: #{c.finding} (#{c.stat})" }.join("\n")
    cards_text = "(none)" if cards_text.empty?

    company_avg_turnover = company_average("turnover", "rate")

    <<~PROMPT
      You are briefing a senior communications lead at Flowt.

      Department: #{@department.name}
      Headcount: #{headcount || 'unknown'}
      Turnover rate: #{format_pct(turnover_rate)} (company avg: #{format_pct(company_avg_turnover)})
      Engagement score: #{engagement&.round(2) || '—'}/5.0 (trend: #{trend_direction})
      Event attendance: #{format_pct(attendance)}
      Top feedback themes: #{themes.any? ? themes.join(', ') : '(none)'}
      Preferred communication channel: #{pref_channel || 'unknown'}

      Active critical/warning insights:
      #{cards_text}

      Write a 3-4 sentence plain-English brief. Lead with the single most urgent finding.
      Reference specific numbers. End with one forward-looking observation.
      Do not use bullet points. Stay under 100 words. Do not start with a greeting.
    PROMPT
  end

  def fallback_summary
    snapshot = @department.department_profile&.snapshot_data || {}
    cards = InsightEngineService.call(@department)
    headline = cards.find { |c| c.severity == :critical } || cards.find { |c| c.severity == :warning }

    eng = snapshot.dig("engagement", "average")
    rate = snapshot.dig("turnover", "rate")
    att = snapshot.dig("events", "attendance_rate")

    parts = []
    if headline
      parts << "#{@department.name} shows #{headline.severity} indicators: #{headline.finding.downcase} (#{headline.stat})."
    else
      parts << "#{@department.name} is performing within normal ranges across the tracked metrics."
    end
    parts << "Engagement averages #{eng&.round(2) || '—'}/5.0 across #{snapshot.dig('engagement', 'sample_size') || 0} responses, " \
             "turnover sits at #{format_pct(rate)}, and event attendance is #{format_pct(att)}."

    themes = (snapshot.dig("feedback", "themes") || []).first(2).map { |t| t["term"] }
    parts << "Recurring feedback themes — #{themes.join(', ')} — should guide the next communication cycle." if themes.any?

    parts << "Continue monitoring the trend lines into the next reporting period."
    parts.join(" ")
  end

  def company_average(section, key)
    rates = Department.includes(:department_profile).filter_map do |d|
      d.department_profile&.snapshot_data&.dig(section, key)
    end
    return nil if rates.empty?

    rates.sum / rates.size.to_f
  end

  def format_pct(value)
    return "—" if value.nil?

    "#{(value * 100).round(1)}%"
  end

  def compute_fingerprint
    snapshot = @department.department_profile&.snapshot_data || {}
    refreshed = @department.department_profile&.refreshed_at&.to_i
    payload = {
      department: @department.name,
      refreshed_at: refreshed,
      snapshot: snapshot
    }.to_json
    Digest::MD5.hexdigest(payload)
  end
end
