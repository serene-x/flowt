require "rails_helper"

RSpec.describe RecommendationsService do
  let(:department) { Department.create!(name: "Engineering") }

  def with_snapshot(snapshot)
    profile = department.department_profile || department.build_department_profile
    profile.snapshot_data = snapshot
    profile.refreshed_at = Time.current
    profile.save!
  end

  it "recommends pulse survey when turnover high AND engagement low" do
    with_snapshot(
      "turnover" => { "rate" => 0.30, "average_tenure_months" => 24 },
      "engagement" => { "average" => 2.7 },
      "events" => {}, "feedback" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    actions = recs.map(&:action)
    expect(actions).to include(match(/pulse survey/i))
    high_priority = recs.select { |r| r.priority == :high }
    expect(high_priority).not_to be_empty
  end

  it "recommends onboarding investigation when turnover high AND short tenure" do
    with_snapshot(
      "turnover" => { "rate" => 0.30, "average_tenure_months" => 8 },
      "engagement" => { "average" => 3.5 },
      "events" => {}, "feedback" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/onboarding/i))
  end

  it "recommends async formats when attendance low" do
    with_snapshot(
      "events" => { "attendance_rate" => 0.30 },
      "turnover" => {}, "engagement" => {}, "feedback" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/async/i))
  end

  it "flags negative sentiment around top theme" do
    with_snapshot(
      "feedback" => {
        "sentiment_breakdown" => { "positive" => 1, "neutral" => 1, "negative" => 5 },
        "themes" => [{ "term" => "compensation", "weight" => 4 }]
      },
      "turnover" => {}, "engagement" => {}, "events" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/compensation/))
  end

  it "escalates on consecutive engagement decline" do
    with_snapshot(
      "engagement" => { "average" => 3.0, "by_date" => { "2025-01" => 4.5, "2025-02" => 4.0, "2025-03" => 3.5 } },
      "turnover" => {}, "events" => {}, "feedback" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/Escalate/i))
  end

  it "consolidates communications when one channel dominates" do
    with_snapshot(
      "communications" => { "channel_distribution" => { "Slack" => 18, "Email" => 2 } },
      "turnover" => {}, "engagement" => {}, "events" => {}, "feedback" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/Consolidate communications to Slack/))
  end

  it "issues all-clear when everything healthy" do
    with_snapshot(
      "engagement" => { "average" => 4.4 },
      "events" => { "attendance_rate" => 0.85 },
      "feedback" => { "sentiment_breakdown" => { "positive" => 8, "neutral" => 1, "negative" => 1 } },
      "turnover" => { "rate" => 0.05 }, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    expect(recs.map(&:action)).to include(match(/No immediate actions needed/))
    expect(recs.map(&:priority)).to include(:low)
  end

  it "orders recommendations by priority high → medium → low" do
    with_snapshot(
      "turnover" => { "rate" => 0.30, "average_tenure_months" => 8 },
      "engagement" => { "average" => 2.7 },
      "events" => { "attendance_rate" => 0.30 },
      "feedback" => {}, "communications" => {}
    )
    recs = described_class.call(department, insight_cards: [])
    priorities = recs.map(&:priority_rank)
    expect(priorities).to eq(priorities.sort)
  end
end
