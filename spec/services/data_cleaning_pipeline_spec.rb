require "rails_helper"

RSpec.describe DataCleaningPipeline do
  it "drops fully empty rows" do
    rows = [
      { "id" => "1", "name" => "Ada" },
      { "id" => "", "name" => "" },
      { "id" => "2", "name" => "Bea" }
    ]
    columns = [{ name: "id", data_type: "categorical" }, { name: "name", data_type: "text" }]

    result = described_class.call(rows, columns)

    expect(result.rows.size).to eq(2)
    expect(result.diff.first[:change]).to eq("drop_empty_rows")
  end

  it "trims whitespace inside string fields" do
    rows = [{ "name" => "  Ada  Lovelace " }]
    columns = [{ name: "name", data_type: "text" }]

    result = described_class.call(rows, columns)

    expect(result.rows.first["name"]).to eq("Ada Lovelace")
    expect(result.diff.find { |d| d[:change] == "trim_whitespace" }[:count]).to eq(1)
  end

  it "normalizes dates to ISO 8601" do
    rows = [{ "joined" => "01/15/2025" }, { "joined" => "02/01/2025" }]
    columns = [{ name: "joined", data_type: "date" }]

    result = described_class.call(rows, columns)

    expect(result.rows.map { |r| r["joined"] }).to eq(["2025-01-15", "2025-02-01"])
  end

  it "standardizes case-variant categoricals to a canonical form" do
    rows = [
      { "department" => "Engineering" },
      { "department" => "engineering" },
      { "department" => "ENGINEERING" },
      { "department" => "Marketing" }
    ]
    columns = [{ name: "department", data_type: "categorical" }]

    result = described_class.call(rows, columns)

    departments = result.rows.map { |r| r["department"] }
    expect(departments.first(3).uniq).to eq(["Engineering"])
  end

  it "flags numeric outliers without removing them" do
    rows = (1..10).map { |i| { "score" => i.to_s } } + [{ "score" => "100" }]
    columns = [{ name: "score", data_type: "numeric" }]

    result = described_class.call(rows, columns)
    expect(result.rows.size).to eq(11)
    flagged = result.rows.select { |r| r["__flags__"]&.any? { |f| f[:kind] == "outlier" } }
    expect(flagged.size).to eq(1)
  end

  it "flags rows with duplicate employee ids" do
    rows = [
      { "employee_id" => "E1", "score" => "4" },
      { "employee_id" => "E2", "score" => "3" },
      { "employee_id" => "E1", "score" => "5" }
    ]
    columns = [
      { name: "employee_id", data_type: "categorical" },
      { name: "score", data_type: "numeric" }
    ]

    result = described_class.call(rows, columns)
    flagged = result.rows.select { |r| r["__flags__"]&.any? { |f| f[:kind] == "duplicate_id" } }
    expect(flagged.size).to eq(2)
  end
end
