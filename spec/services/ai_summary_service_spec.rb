require "rails_helper"

RSpec.describe AiSummaryService do
  let(:department) { Department.create!(name: "Engineering") }

  before do
    profile = department.build_department_profile
    profile.snapshot_data = {
      "headcount" => { "total" => 8 },
      "engagement" => { "average" => 4.0, "sample_size" => 12, "by_date" => { "2025-01" => 3.8, "2025-02" => 4.0 } },
      "turnover" => { "rate" => 0.20, "exits" => 4, "average_tenure_months" => 18 },
      "events" => { "attendance_rate" => 0.78, "events" => 6 },
      "feedback" => {
        "sentiment_breakdown" => { "positive" => 5, "neutral" => 2, "negative" => 3 },
        "themes" => [{ "term" => "leadership", "weight" => 3 }]
      },
      "communications" => { "preferred_channel" => "Slack" }
    }
    profile.refreshed_at = Time.current
    profile.save!
  end

  context "when ANTHROPIC_API_KEY is missing" do
    before { ENV.delete("ANTHROPIC_API_KEY") }

    it "uses fallback rule-based summary" do
      result = described_class.call(department)
      expect(result.source).to eq("fallback")
      expect(result.summary_text).to include("Engineering")
      expect(AiSummary.find_by(department_id: department.id)).to be_present
    end
  end

  context "when Claude API call succeeds" do
    before do
      ENV["ANTHROPIC_API_KEY"] = "test-key"
      allow_any_instance_of(described_class)
        .to receive(:call_claude).and_return("This is a Claude-generated summary.")
    end

    after { ENV.delete("ANTHROPIC_API_KEY") }

    it "calls Claude and stores result" do
      result = described_class.call(department)
      expect(result.source).to eq("claude")
      expect(result.summary_text).to eq("This is a Claude-generated summary.")
    end
  end

  context "when Claude API fails" do
    before do
      ENV["ANTHROPIC_API_KEY"] = "test-key"
      allow_any_instance_of(described_class).to receive(:call_claude).and_raise(StandardError, "boom")
    end

    after { ENV.delete("ANTHROPIC_API_KEY") }

    it "falls back to rule-based summary" do
      result = described_class.call(department)
      expect(result.source).to eq("fallback")
    end
  end

  describe "caching" do
    before { ENV.delete("ANTHROPIC_API_KEY") }

    it "returns cached result when fingerprint matches" do
      first = described_class.call(department)
      expect(first.cached).to be false

      second = described_class.call(department)
      expect(second.cached).to be true
      expect(second.summary_text).to eq(first.summary_text)
    end

    it "regenerates when force: true" do
      described_class.call(department)
      forced = described_class.call(department, force: true)
      expect(forced.cached).to be false
    end

    it "regenerates when fingerprint changes" do
      described_class.call(department)
      profile = department.department_profile
      profile.update!(snapshot_data: profile.snapshot_data.merge("turnover" => { "rate" => 0.40 }), refreshed_at: 1.minute.from_now)
      result = described_class.call(department)
      expect(result.cached).to be false
    end
  end
end
