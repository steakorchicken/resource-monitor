import SwiftUI
import Charts

struct ChartSeries: Identifiable {
    var id: String { name }
    let name: String
    let values: [Double]
    let color: Color
}

/// Rounds up to 1/2/5 × 10ⁿ so auto-scaled axes have readable maxima.
func niceMax(_ value: Double, minimum: Double) -> Double {
    let x = max(value * 1.1, minimum)
    let p = pow(10, (log10(x)).rounded(.down))
    let n = x / p
    let m: Double = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10
    return m * p
}

/// Task-Manager style 60-second chart: gradient area under a line, faint gridlines, no animation.
struct LiveChartView: View {
    let series: [ChartSeries]
    let yMax: Double
    var yLabel: (Double) -> String = { String(format: "%.0f", $0) }
    var height: CGFloat = 200
    var capacity: Int = MonitorStore.historyCapacity

    var body: some View {
        Chart {
            ForEach(series) { s in
                ForEach(Array(s.values.enumerated()), id: \.offset) { index, value in
                    let x = capacity - s.values.count + index
                    let y = min(max(value, 0), yMax)
                    AreaMark(x: .value("Time", x), y: .value("Value", y), series: .value("Series", s.name + "a"))
                        .foregroundStyle(LinearGradient(colors: [s.color.opacity(0.35), s.color.opacity(0)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Time", x), y: .value("Value", y), series: .value("Series", s.name))
                        .foregroundStyle(s.color)
                        .lineStyle(StrokeStyle(lineWidth: 1.75, lineJoin: .round))
                }
            }
        }
        .chartXScale(domain: 0...(capacity - 1))
        .chartYScale(domain: 0...yMax)
        .chartXAxis {
            AxisMarks(values: [0, 15, 30, 45, capacity - 1]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.gridline)
                AxisValueLabel(anchor: value.as(Int.self) == 0 ? .topLeading : (value.as(Int.self) == capacity - 1 ? .topTrailing : .top)) {
                    if let v = value.as(Int.self), v == 0 || v == capacity - 1 {
                        Text(v == 0 ? "60 seconds" : "0").font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, yMax / 2, yMax]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(Theme.gridline)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yLabel(v)).font(.caption2).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .chartPlotStyle { $0.background(Color.clear).border(Theme.gridline, width: 1) }
        .transaction { $0.animation = nil }
        .frame(height: height)
    }
}
