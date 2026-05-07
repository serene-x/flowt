class DepartmentsController < ApplicationController
  before_action :load_department, only: [:show, :refresh, :export_pdf, :export_csv, :regenerate_summary, :export_full_pdf]

  def index
    @departments = Department.order(:name).includes(:datasets, :department_profile)
  end

  def show
    @profile = @department.department_profile || DepartmentProfileService.refresh(@department)
    @datasets = @department.relevant_datasets.order(:dataset_type)
    @section = params[:section].presence || "overview"
    @company_averages = compute_company_averages
    @insight_cards = InsightEngineService.call(@department, company_averages: @company_averages)
    @recommendations = RecommendationsService.call(@department, insight_cards: @insight_cards)
    @ai_summary = load_ai_summary
  end

  def refresh
    DepartmentProfileService.refresh(@department)
    redirect_to department_path(@department), notice: "Profile refreshed."
  end

  def regenerate_summary
    AiSummaryService.call(@department, force: true)
    redirect_to department_path(@department), notice: "Summary regenerated."
  rescue StandardError => e
    redirect_to department_path(@department), alert: "Could not regenerate summary: #{e.message}"
  end

  def export_csv
    profile = @department.department_profile&.snapshot_data || {}
    csv_data = DepartmentProfileExporter.to_csv(@department, profile)
    send_data csv_data, type: "text/csv", filename: "#{@department.slug}-profile.csv"
  end

  def export_pdf
    profile = @department.department_profile&.snapshot_data || {}
    pdf = DepartmentProfileExporter.to_pdf(@department, profile)
    send_data pdf, type: "application/pdf", filename: "#{@department.slug}-comms.pdf"
  end

  def export_full_pdf
    pdf = FullReportExporter.call(@department)
    send_data pdf, type: "application/pdf", filename: "#{@department.slug}-full-report.pdf"
  end

  private

  def load_department
    @department = Department.find_by(slug: params[:slug])

    unless @department
      # Stale slug — convert back to a name and fuzzy-match to a live department
      guessed_name = params[:slug].to_s.tr("-", " ").split.map(&:capitalize).join(" ")
      canonical = Department.normalize_name(guessed_name)
      @department = Department.find_by("LOWER(name) = ?", canonical.downcase) ||
                    Department.fuzzy_match(canonical)
      if @department
        redirect_to department_path(@department), status: :moved_permanently and return
      else
        raise ActiveRecord::RecordNotFound
      end
    end
  end

  def compute_company_averages
    InsightEngineService.company_averages
  end

  def load_ai_summary
    AiSummaryService.call(@department)
  rescue StandardError => e
    Rails.logger.warn("AI summary failed: #{e.message}")
    nil
  end
end
