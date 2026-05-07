require "rails_helper"

RSpec.describe InsightEngineService do
  let(:department) { Department.create!(name: "Engineering") }

  def with_snapshot(snapshot)
    profile = department.department_profile || department.build_department_profile
    profile.snapshot_data = snapshot
    profile.refreshed_at = Time.current
    profile.save!
    profile
  end

  describe "turnover rules" do
    it "flags critical when turnover > 25%" do
      with_snapshot("turnover" => { "rate" => 0.34 }, "engagement" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: { turnover: 0.18, engagement: 3.5, attendance: 0.7 })
      expect(cards.map(&:severity)).to include(:critical)
      expect(cards.find { |c| c.severity == :critical }.finding).to match(/critically high/)
    end

    it "flags warning when turnover > 15% and above company avg" do
      with_snapshot("turnover" => { "rate" => 0.18 }, "engagement" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: { turnover: 0.10, engagement: 3.5, attendance: 0.7 })
      expect(cards.map(&:finding)).to include(match(/above company average/))
    end

    it "flags positive when turnover < 10%" do
      with_snapshot("turnover" => { "rate" => 0.05 }, "engagement" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: { turnover: 0.18, engagement: 3.5, attendance: 0.7 })
      expect(cards.map(&:severity)).to include(:positive)
    end
  end

  describe "engagement rules" do
    it "flags critical when score < 3.0" do
      with_snapshot("engagement" => { "average" => 2.5 }, "turnover" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/below acceptable/))
    end

    it "flags warning when engagement dropped > 15% vs previous period" do
      with_snapshot("engagement" => { "average" => 3.5, "by_date" => { "2025-01" => 4.0, "2025-02" => 3.2 } },
                    "turnover" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/declined significantly/))
    end

    it "flags positive when engagement improved > 15% vs previous period" do
      with_snapshot("engagement" => { "average" => 4.5, "by_date" => { "2025-01" => 3.5, "2025-02" => 4.5 } },
                    "turnover" => {}, "events" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/trending upward/))
    end
  end

  describe "attendance rules" do
    it "flags warning when attendance < 40%" do
      with_snapshot("events" => { "attendance_rate" => 0.30 },
                    "engagement" => {}, "turnover" => {}, "feedback" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/attendance is low/))
    end
  end

  describe "sentiment rules" do
    it "flags critical when negative > 50%" do
      with_snapshot("feedback" => { "sentiment_breakdown" => { "positive" => 1, "neutral" => 1, "negative" => 8 } },
                    "engagement" => {}, "turnover" => {}, "events" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/Majority of feedback is negative/))
    end

    it "flags positive when positive > 70%" do
      with_snapshot("feedback" => { "sentiment_breakdown" => { "positive" => 8, "neutral" => 1, "negative" => 1 } },
                    "engagement" => {}, "turnover" => {}, "events" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:severity)).to include(:positive)
    end

    it "flags warning when negative > 30% but ≤ 50%" do
      with_snapshot("feedback" => { "sentiment_breakdown" => { "positive" => 4, "neutral" => 2, "negative" => 4 } },
                    "engagement" => {}, "turnover" => {}, "events" => {})
      cards = described_class.call(department, company_averages: {})
      expect(cards.map(&:finding)).to include(match(/sentiment is elevated/))
    end
  end

  it "returns an empty array when nothing meets the rules" do
    with_snapshot({})
    cards = described_class.call(department, company_averages: {})
    expect(cards).to eq([])
  end
end
