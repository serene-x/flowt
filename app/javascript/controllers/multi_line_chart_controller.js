import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Array }

  connect() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas || !this.dataValue || this.dataValue.length === 0) return

    const h = parseInt(canvas.getAttribute("height") || "200", 10)
    this.element.style.position = "relative"
    this.element.style.height = h + "px"

    const allLabels = new Set()
    this.dataValue.forEach(s => Object.keys(s.data || {}).forEach(k => allLabels.add(k)))
    const labels = [...allLabels].sort()

    const datasets = this.dataValue.map(series => ({
      label: series.name,
      data: labels.map(l => series.data[l] ?? null),
      borderColor: series.color || "#6366f1",
      backgroundColor: (series.color || "#6366f1") + "22",
      tension: 0.3,
      fill: false,
      pointRadius: 3,
      pointBackgroundColor: series.color || "#6366f1",
      pointBorderColor: "#fff",
      pointBorderWidth: 1.5,
      spanGaps: true
    }))

    this.chart = new Chart(canvas, {
      type: "line",
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            align: "end",
            labels: { color: "#57534e", font: { size: 11 }, boxWidth: 12, padding: 8 }
          }
        },
        scales: {
          x: { grid: { display: false }, ticks: { color: "#78716c", font: { size: 10 } } },
          y: { grid: { color: "#f5f5f4" }, ticks: { color: "#78716c", font: { size: 10 } } }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
