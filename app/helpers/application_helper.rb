module ApplicationHelper
  def status_pill_classes(status)
    base = "inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-semibold"
    color = case status.to_s
            when "ready" then "bg-emerald-100 text-emerald-700"
            when "processing" then "bg-amber-100 text-amber-700"
            when "failed" then "bg-rose-100 text-rose-700"
            else "bg-stone-100 text-stone-600"
            end
    "#{base} #{color}"
  end

  def sentiment_pill(sentiment)
    color = case sentiment.to_s
            when "positive" then "bg-emerald-100 text-emerald-700"
            when "negative" then "bg-rose-100 text-rose-700"
            else "bg-stone-100 text-stone-600"
            end
    content_tag :span, sentiment.to_s.titleize, class: "inline-flex items-center px-2 py-0.5 rounded-full text-[11px] font-semibold #{color}"
  end

  def engagement_text_class(score)
    case ThresholdService.engagement_band(score)
    when :healthy then "text-emerald-700"
    when :critical then "text-rose-700"
    when :neutral then "text-amber-700"
    else "text-stone-900"
    end
  end

  def format_percent(value, digits: 1)
    return "—" if value.nil?

    "#{(value * 100).round(digits)}%"
  end

  def dataset_type_badge(type)
    color = case type.to_s
            when "engagement" then "bg-indigo-50 text-indigo-700 border-indigo-100"
            when "turnover" then "bg-rose-50 text-rose-700 border-rose-100"
            when "events" then "bg-amber-50 text-amber-700 border-amber-100"
            when "feedback" then "bg-sky-50 text-sky-700 border-sky-100"
            when "communications" then "bg-emerald-50 text-emerald-700 border-emerald-100"
            else "bg-stone-50 text-stone-600 border-stone-200"
            end
    content_tag :span, type.to_s.titleize, class: "inline-flex items-center border px-2.5 py-0.5 rounded-full text-[11px] font-semibold #{color}"
  end
end
