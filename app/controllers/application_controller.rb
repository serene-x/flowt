class ApplicationController < ActionController::Base
  before_action :load_sidebar_departments

  private

  def load_sidebar_departments
    @sidebar_departments = Department.order(:name).includes(:datasets, :department_profile)
  end
end
