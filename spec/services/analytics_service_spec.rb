require "rails_helper"

RSpec.describe AnalyticsService do
  let(:dataset) { Dataset.create!(name: "T", dataset_type: "custom", status: :ready) }

  def add_column(name, type)
    dataset.dataset_columns.create!(name: name, position: dataset.dataset_columns.size, data_type: DatasetColumn.data_types[type])
  end

  def add_rows(values_for_key, key)
    values_for_key.each_with_index { |v, i| dataset.data_rows.create!(row_index: i, data: { key => v }) }
  end

  describe "numeric stats" do
    it "computes min, max, mean, median, and a histogram" do
      column = add_column("score", "numeric")
      [1.0, 2.0, 2.0, 3.0, 4.0, 5.0].each_with_index do |v, i|
        dataset.data_rows.create!(row_index: i, data: { "score" => v.to_s })
      end

      stats = described_class.column_stats(column, dataset.data_rows.to_a)

      expect(stats[:type]).to eq("numeric")
      expect(stats[:min]).to eq(1.0)
      expect(stats[:max]).to eq(5.0)
      expect(stats[:mean]).to be_within(0.001).of(2.833)
      expect(stats[:histogram].sum { |b| b[:count] }).to eq(6)
    end

    it "handles all-null numeric columns" do
      column = add_column("score", "numeric")
      3.times { |i| dataset.data_rows.create!(row_index: i, data: { "score" => nil }) }
      stats = described_class.column_stats(column, dataset.data_rows.to_a)
      expect(stats[:null_count]).to eq(3)
      expect(stats[:mean]).to be_nil
    end
  end

  describe "categorical stats" do
    it "produces top values capped at 10" do
      column = add_column("dept", "categorical")
      values = ["Eng"] * 5 + ["Mkt"] * 3 + ["Sales"] * 2
      values.each_with_index { |v, i| dataset.data_rows.create!(row_index: i, data: { "dept" => v }) }

      stats = described_class.column_stats(column, dataset.data_rows.to_a)
      labels = stats[:top_values].map { |x| x[:label] }
      expect(labels.first).to eq("Eng")
      expect(stats[:unique_count]).to eq(3)
    end
  end

  describe "global metrics" do
    it "summarizes counts" do
      Department.create!(name: "Engineering")
      metrics = described_class.global_metrics
      expect(metrics).to include(:department_count, :dataset_count, :row_count, :ready_count, :pending_count)
    end
  end
end
