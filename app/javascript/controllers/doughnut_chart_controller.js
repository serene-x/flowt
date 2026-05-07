import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Array, colors: Array }

  connect() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas || !this.dataValue || this.dataValue.length === 0) return

    const h = parseInt(canvas.getAttribute("height") || "200", 10)
    this.element.style.position = "relative"
    this.element.style.height = h + "px"

    const labels = this.dataValue.map(d => d.label)
    const counts = this.dataValue.map(d => d.count)
    const palette = this.hasColorsValue && this.colorsValue.length
      ? this.colorsValue
      : ["#6366f1", "#a8a29e", "#f43f5e", "#10b981", "#f59e0b", "#06b6d4", "#8b5cf6"]

    this.chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels,
        datasets: [{
          data: counts,
          backgroundColor: labels.map((_, i) => palette[i % palette.length]),
          borderColor: "#fff",
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "65%",
        plugins: {
          legend: {
            position: "right",
            labels: { color: "#57534e", font: { size: 11 }, boxWidth: 10, padding: 10 }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
