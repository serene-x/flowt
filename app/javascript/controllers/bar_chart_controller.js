import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = { data: Array, orientation: { type: String, default: "vertical" } }

  connect() {
    const canvas = this.element.querySelector("canvas")
    if (!canvas || !this.dataValue || this.dataValue.length === 0) return

    const h = parseInt(canvas.getAttribute("height") || "200", 10)
    this.element.style.position = "relative"
    this.element.style.height = h + "px"

    const labels = this.dataValue.map(d => d.range)
    const counts = this.dataValue.map(d => d.count)
    const horizontal = this.orientationValue === "horizontal"

    this.chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels,
        datasets: [{
          data: counts,
          backgroundColor: "#6366f1",
          hoverBackgroundColor: "#4f46e5",
          borderRadius: 4,
          barThickness: horizontal ? 18 : "flex"
        }]
      },
      options: {
        indexAxis: horizontal ? "y" : "x",
        responsive: true,
        maintainAspectRatio: false,
        plugins: { legend: { display: false } },
        scales: {
          x: { grid: { display: !horizontal, color: "#f5f5f4" }, ticks: { color: "#78716c", font: { size: 11 } } },
          y: { grid: { display: horizontal, color: "#f5f5f4" }, ticks: { color: "#78716c", font: { size: 11 } } }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
  }
}
