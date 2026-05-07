require "prawn"
require "prawn/table"

class DepartmentProfileExporter
  def self.to_csv(department, profile)
    CSV.generate do |csv|
      csv << ["Flowt profile", department.name]
      csv << ["Generated", Time.current.iso8601]
      csv << []
      flatten(profile).each { |key, value| csv << [key, value] }
    end
  end

  def self.to_pdf(department, profile)
    Prawn::Document.new(page_size: "LETTER", margin: 48) do |pdf|
      pdf.font_families.update("Helvetica" => {
        normal: "Helvetica",
        bold: "Helvetica-Bold",
        italic: "Helvetica-Oblique"
      })
      pdf.font "Helvetica"
      pdf.text "Communications Profile", size: 22, style: :bold
      pdf.text department.name, size: 14
      pdf.move_down 6
      pdf.text "Generated #{Time.current.strftime('%B %-d, %Y')}", size: 9, color: "808080"
      pdf.move_down 18

      comms = profile["communications"] || {}

      pdf.text "Preferred channel: #{comms['preferred_channel'] || '—'}", size: 11
      pdf.text "Preferred update frequency: #{comms['preferred_frequency'] || '—'}", size: 11
      pdf.move_down 12

      if comms["channel_distribution"].is_a?(Hash) && comms["channel_distribution"].any?
        pdf.text "Channel distribution", style: :bold, size: 12
        rows = comms["channel_distribution"].map { |k, v| [k.to_s, v.to_s] }
        pdf.table([["Channel", "Responses"]] + rows, header: true, cell_style: { padding: 6, border_width: 0.4 })
        pdf.move_down 12
      end

      if comms["frequency_distribution"].is_a?(Hash) && comms["frequency_distribution"].any?
        pdf.text "Update frequency", style: :bold, size: 12
        rows = comms["frequency_distribution"].map { |k, v| [k.to_s, v.to_s] }
        pdf.table([["Frequency", "Responses"]] + rows, header: true, cell_style: { padding: 6, border_width: 0.4 })
        pdf.move_down 12
      end

      themes = profile.dig("feedback", "themes") || []
      if themes.any?
        pdf.text "Top themes from feedback", style: :bold, size: 12
        themes.each do |theme|
          pdf.text "— #{theme['term']}", size: 10
        end
      end
    end.render
  end

  def self.flatten(hash, prefix = "")
    hash.flat_map do |key, value|
      composed = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      case value
      when Hash then flatten(value, composed)
      else [[composed, value.to_s]]
      end
    end
  end
end
