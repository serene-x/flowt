import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Object }

  connect() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas) return
    const entries = Object.entries(this.dataValue || {})
    if (entries.length === 0) return

    const h = parseInt(canvas.getAttribute("height") || "200", 10)
    this.element.style.position = "relative"
    this.element.style.height = h + "px"

    this.chart = new Chart(canvas, {
      type: "line",
      data: {
        labels: entries.map(([k]) => k),
        datasets: [{
          data: entries.map(([, v]) => v),
          borderColor: "#6366f1",
          backgroundColor: "rgba(99, 102, 241, 0.08)",
          tension: 0.3,
          fill: true,
          pointRadius: 4,
          pointBackgroundColor: "#6366f1",
          pointBorderColor: "#fff",
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: false }, ticks: { color: "#78716c", font: { size: 11 } } },
          y: { grid: { color: "#f5f5f4" }, ticks: { color: "#78716c", font: { size: 11 } } }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
