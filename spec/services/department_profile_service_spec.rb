require "rails_helper"

RSpec.describe DepartmentProfileService do
  let(:department) { Department.create!(name: "Engineering") }

  def seed_engagement(values)
    dataset = Dataset.create!(name: "E", dataset_type: "engagement", status: :ready)
    dataset.dataset_columns.create!(name: "department", position: 0, data_type: DatasetColumn.data_types["categorical"])
    dataset.dataset_columns.create!(name: "engagement_score", position: 1, data_type: DatasetColumn.data_types["numeric"])
    dataset.dataset_columns.create!(name: "satisfaction_score", position: 2, data_type: DatasetColumn.data_types["numeric"])
    dataset.dataset_columns.create!(name: "employee_id", position: 3, data_type: DatasetColumn.data_types["categorical"])
    values.each_with_index do |(eng, sat, emp), i|
      dataset.data_rows.create!(
        row_index: i,
        data: { "department" => "Engineering", "engagement_score" => eng.to_s, "satisfaction_score" => sat.to_s, "employee_id" => emp }
      )
    end
  end

  it "computes engagement averages from rows tagged to the department" do
    seed_engagement([[4.0, 4.0, "E1"], [3.5, 3.5, "E2"], [4.5, 4.5, "E3"]])

    profile = described_class.refresh(department)
    expect(profile.snapshot_data["engagement"]["average"]).to eq(4.0)
    expect(profile.snapshot_data["engagement"]["sample_size"]).to eq(3)
    expect(profile.snapshot_data["headcount"]["total"]).to eq(3)
  end

  it "writes empty sections when no data is present" do
    profile = described_class.refresh(department)
    expect(profile.snapshot_data["engagement"]).to eq({})
    expect(profile.snapshot_data["turnover"]).to eq({ "rate" => nil, "exits" => 0 })
  end

  it "is idempotent on repeated calls" do
    seed_engagement([[4.0, 4.0, "E1"]])
    described_class.refresh(department)
    expect { described_class.refresh(department) }.not_to change(DepartmentProfile, :count)
  end
end
