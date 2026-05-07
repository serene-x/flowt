require "rails_helper"

RSpec.describe TextAnalyticsService do
  it "scores positive and negative responses with the lexicon" do
    expect(described_class.score("The team is great and supportive")).to eq("positive")
    expect(described_class.score("Process is unclear and frustrating")).to eq("negative")
    expect(described_class.score("This is a sentence.")).to eq("neutral")
  end

  it "returns frequency-ordered keywords with stop words removed" do
    summary = described_class.summarize([
      "The team feels supported and engaged.",
      "Team alignment is improving across the team."
    ])

    keyword_words = summary["keywords"].map { |k| k["word"] }
    expect(keyword_words).to include("team")
    expect(keyword_words).not_to include("the")
  end

  it "summarizes sentiment breakdown across responses" do
    summary = described_class.summarize([
      "Excellent culture and great team",
      "Frustrating and unclear",
      "We met today"
    ])

    expect(summary["sentiment_breakdown"]).to include(
      "positive" => be >= 1,
      "negative" => be >= 1
    )
  end

  it "returns empty hash for empty input" do
    expect(described_class.summarize([])).to eq({})
  end
end
