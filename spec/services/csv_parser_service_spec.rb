require "rails_helper"

RSpec.describe CsvParserService do
  def parse(csv)
    described_class.call(StringIO.new(csv))
  end

  it "detects numeric columns above the threshold" do
    result = parse(<<~CSV)
      id,score
      1,4.2
      2,3.8
      3,4.0
      4,3.5
    CSV
    types = result.columns.to_h { |c| [c[:name], c[:data_type]] }
    expect(types).to eq("id" => "numeric", "score" => "numeric")
  end

  it "detects date columns" do
    result = parse(<<~CSV)
      id,joined
      1,2025-01-15
      2,2025-02-01
      3,2025-03-12
    CSV
    expect(result.columns.find { |c| c[:name] == "joined" }[:data_type]).to eq("date")
  end

  it "treats low-cardinality strings as categorical" do
    result = parse(<<~CSV)
      id,department
      1,Engineering
      2,Engineering
      3,Marketing
      4,Engineering
      5,Marketing
    CSV
    expect(result.columns.find { |c| c[:name] == "department" }[:data_type]).to eq("categorical")
  end

  it "captures preview of first 10 rows only" do
    rows = (1..15).map { |i| "#{i},val#{i}" }.join("\n")
    result = parse("id,name\n#{rows}")
    expect(result.preview.size).to eq(10)
    expect(result.total_rows).to eq(15)
  end

  it "warns about missing values and duplicate employee_ids" do
    result = parse(<<~CSV)
      employee_id,score
      E1,4.0
      E2,
      E1,3.5
    CSV
    kinds = result.warnings.map { |w| w[:kind] }
    expect(kinds).to include("missing_values")
    expect(kinds).to include("duplicate_ids")
  end

  it "returns empty result for empty CSV" do
    result = parse("")
    expect(result.total_rows).to eq(0)
    expect(result.warnings.map { |w| w[:kind] }).to include("empty_file")
  end
end
