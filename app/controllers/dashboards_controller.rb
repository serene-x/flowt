class DashboardsController < ApplicationController
  RECENT_DATASETS_LIMIT = 6

  def show
    @metrics = AnalyticsService.global_metrics
    @rows, @averages = BenchmarkService.call
    @benchmark_slug = params[:benchmark_against].presence
    @benchmark = pick_benchmark(@benchmark_slug)
    @benchmark[:engagement_n] = @rows.count { |r| r.engagement.present? }
    @sort = params[:sort].presence_in(%w[name headcount turnover engagement attendance sentiment last_updated]) || "name"
    @direction = params[:dir] == "desc" ? "desc" : "asc"
    @rows = sort_rows(@rows, @sort, @direction)
    @recent_datasets = Dataset.recent.limit(RECENT_DATASETS_LIMIT)
  end

  def comparison
    @comparison = AnalyticsService.department_comparison
  end

  private

  def pick_benchmark(slug)
    return @averages if slug.blank? || slug == "company"

    department = Department.find_by(slug: slug)
    return @averages unless department

    BenchmarkService.build_row(department).tap do |row|
      return {
        name: row.name,
        headcount: row.headcount,
        turnover: row.turnover,
        engagement: row.engagement,
        attendance: row.attendance,
        sentiment_pos_share: row.sentiment_pos_share
      }
    end
  end

  def sort_rows(rows, key, direction)
    sorter = case key
             when "headcount" then ->(r) { r.headcount.to_i }
             when "turnover" then ->(r) { r.turnover.to_f }
             when "engagement" then ->(r) { r.engagement.to_f }
             when "attendance" then ->(r) { r.attendance.to_f }
             when "sentiment" then ->(r) { r.sentiment_pos_share.to_f }
             when "last_updated" then ->(r) { r.last_updated || Time.at(0) }
             else ->(r) { r.name.to_s.downcase }
             end
    sorted = rows.sort_by(&sorter)
    direction == "desc" ? sorted.reverse : sorted
  end
end
