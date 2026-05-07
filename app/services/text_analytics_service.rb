class TextAnalyticsService
  STOP_WORDS = %w[
    a an the and or but if of to in on at for with by from as is are was were be been being
    have has had do does did will would could should may might can shall i you he she it we they
    me him her us them my your his hers its our their this that these those there here so not no
    yes too very just up down out into about over after before more most some any all each every
    own same than then now also still while although though because while during who whom which
    what when where why how
  ].to_set.freeze

  POSITIVE_WORDS = %w[
    great excellent good love loved supported supportive collaborative collaboration trust trusted
    autonomy autonomous fair clear helpful productive sustainable strong solid hitting fair best
    inspired engaged enjoy enjoying happy positive enthusiastic motivated proud confident thriving
    learning grow growing high quality successful winning improving improved valued appreciated
  ].to_set.freeze

  NEGATIVE_WORDS = %w[
    bad poor frustrating frustrated unclear disconnected overwhelmed brutal burnt unrealistic
    rushed crashed crashes crashing slow disruptive thrown unsustainable below low losing left
    leaving struggling struggle worried concerned exhausted exhausting tired tough hard difficult
    impossible never lacking lack misaligned poor blocked blocker stuck broken stressed stressful
  ].to_set.freeze

  def self.summarize(texts)
    new(texts).summarize
  end

  def self.score(text)
    new([text]).response_sentiment(text)
  end

  def initialize(texts)
    @texts = Array(texts).map { |t| t.to_s.strip }.reject(&:empty?)
  end

  def summarize
    return {} if @texts.empty?

    keywords = keyword_frequencies
    sentiments = @texts.map { |t| response_sentiment(t) }
    breakdown = sentiments.tally

    {
      "response_count" => @texts.size,
      "keywords" => keywords.first(20).map { |word, count| { "word" => word, "count" => count } },
      "sentiment_breakdown" => {
        "positive" => breakdown["positive"].to_i,
        "neutral" => breakdown["neutral"].to_i,
        "negative" => breakdown["negative"].to_i
      },
      "themes" => derive_themes(keywords).first(5),
      "wordcloud" => keywords.first(40).map { |word, count| { "word" => word, "count" => count } }
    }
  end

  def response_sentiment(text)
    tokens = tokenize(text)
    pos = tokens.count { |w| POSITIVE_WORDS.include?(w) }
    neg = tokens.count { |w| NEGATIVE_WORDS.include?(w) }

    return "positive" if pos - neg > 1
    return "negative" if neg - pos > 1

    "neutral"
  end

  private

  def keyword_frequencies
    frequencies = Hash.new(0)
    @texts.each do |text|
      tokenize(text).each do |token|
        next if STOP_WORDS.include?(token)
        next if token.length < 3

        frequencies[token] += 1
      end
    end
    frequencies.sort_by { |_, c| -c }
  end

  def tokenize(text)
    text.downcase.scan(/[a-z][a-z\-']+/)
  end

  def derive_themes(keywords)
    keywords.first(20).map do |word, count|
      { "term" => word, "weight" => count }
    end
  end
end
