require "rails_helper"

RSpec.describe ThresholdService do
  describe ".turnover_band" do
    it "returns critical above 25%" do
      expect(described_class.turnover_band(0.30)).to eq(:critical)
    end

    it "returns warning above 15%" do
      expect(described_class.turnover_band(0.20)).to eq(:warning)
    end

    it "returns healthy below 10%" do
      expect(described_class.turnover_band(0.05)).to eq(:healthy)
    end

    it "returns neutral in between" do
      expect(described_class.turnover_band(0.12)).to eq(:neutral)
    end

    it "returns unknown for nil" do
      expect(described_class.turnover_band(nil)).to eq(:unknown)
    end
  end

  describe ".engagement_band" do
    it "is critical below 3.0" do
      expect(described_class.engagement_band(2.5)).to eq(:critical)
    end

    it "is healthy at or above 4.0" do
      expect(described_class.engagement_band(4.2)).to eq(:healthy)
    end

    it "is neutral in mid range" do
      expect(described_class.engagement_band(3.5)).to eq(:neutral)
    end
  end

  describe ".attendance_band" do
    it "is warning below 40%" do
      expect(described_class.attendance_band(0.30)).to eq(:warning)
    end

    it "is healthy at or above 75%" do
      expect(described_class.attendance_band(0.85)).to eq(:healthy)
    end

    it "is neutral in mid range" do
      expect(described_class.attendance_band(0.60)).to eq(:neutral)
    end
  end

  describe ".sentiment_band" do
    it "is critical when negative > 50%" do
      expect(described_class.sentiment_band("positive" => 1, "neutral" => 1, "negative" => 6)).to eq(:critical)
    end

    it "is healthy when positive > 70%" do
      expect(described_class.sentiment_band("positive" => 8, "neutral" => 1, "negative" => 1)).to eq(:healthy)
    end

    it "is unknown for empty" do
      expect(described_class.sentiment_band({})).to eq(:unknown)
    end
  end

  describe ".trend_direction" do
    it "returns :up when current is meaningfully higher" do
      expect(described_class.trend_direction(4.5, 4.0)).to eq(:up)
    end

    it "returns :down when current is meaningfully lower" do
      expect(described_class.trend_direction(3.5, 4.0)).to eq(:down)
    end

    it "returns :flat for small changes" do
      expect(described_class.trend_direction(4.05, 4.0)).to eq(:flat)
    end

    it "returns :flat when previous is zero" do
      expect(described_class.trend_direction(1, 0)).to eq(:flat)
    end
  end
end
