import SwiftUI

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
/// Drawn with Canvas rather than Swift Charts: one immediate-mode pass per tick instead of
/// rebuilding ~120 marks per series plus scales and axes.
struct LiveChartView: View {
    let series: [ChartSeries]
    let yMax: Double
    var yLabel: (Double) -> String = { String(format: "%.0f", $0) }
    var height: CGFloat = 200
    var capacity: Int = MonitorStore.historyCapacity

    /// Gridlines at the same positions Swift Charts used: 0, 15, 30, 45 and the newest sample.
    private static let xGrid = [15, 30, 45]
    private static let labelGap: CGFloat = 6

    var body: some View {
        let yMax = max(self.yMax, .ulpOfOne)
        let yLabels = [yMax, yMax / 2, 0].map { yLabel($0) }
        Canvas { context, size in
            func label(_ s: String) -> GraphicsContext.ResolvedText {
                context.resolve(Text(s).font(.caption2).foregroundStyle(Theme.textSecondary))
            }
            let resolvedY = yLabels.map(label)
            let first = label("60 seconds"), last = label("0")
            let labelHeight = max(first.measure(in: size).height, 1)
            let gutter = (resolvedY.map { $0.measure(in: size).width }.max() ?? 0) + Self.labelGap

            // Half a label of headroom so the top y label isn't clipped; x labels sit below the plot.
            let plot = CGRect(x: gutter, y: labelHeight / 2,
                              width: max(size.width - gutter, 1),
                              height: max(size.height - labelHeight / 2 - labelHeight - 4, 1))
            let step = plot.width / CGFloat(max(capacity - 1, 1))
            func y(_ v: Double) -> CGFloat { plot.maxY - CGFloat(min(max(v, 0), yMax) / yMax) * plot.height }

            // Grid and border.
            var grid = Path()
            for i in Self.xGrid where i < capacity - 1 {
                let x = plot.minX + CGFloat(i) * step
                grid.move(to: CGPoint(x: x, y: plot.minY)); grid.addLine(to: CGPoint(x: x, y: plot.maxY))
            }
            grid.move(to: CGPoint(x: plot.minX, y: plot.midY)); grid.addLine(to: CGPoint(x: plot.maxX, y: plot.midY))
            grid.addRect(plot)
            context.stroke(grid, with: .color(Theme.gridline), lineWidth: 1)

            // Axis labels.
            for (text, value) in zip(resolvedY, [yMax, yMax / 2, 0]) {
                context.draw(text, at: CGPoint(x: gutter - Self.labelGap, y: y(value)), anchor: .trailing)
            }
            context.draw(first, at: CGPoint(x: plot.minX + 4, y: plot.maxY + 4), anchor: .topLeading)
            context.draw(last, at: CGPoint(x: plot.maxX - 4, y: plot.maxY + 4), anchor: .topTrailing)

            // Series: gradient area, then the line on top. Newest value is on the right.
            for s in series where s.values.count > 1 {
                let offset = capacity - s.values.count
                var line = Path()
                for (i, v) in s.values.enumerated() {
                    let p = CGPoint(x: plot.minX + CGFloat(offset + i) * step, y: y(v))
                    if i == 0 { line.move(to: p) } else { line.addLine(to: p) }
                }
                var area = line
                area.addLine(to: CGPoint(x: plot.maxX, y: plot.maxY))
                area.addLine(to: CGPoint(x: plot.minX + CGFloat(offset) * step, y: plot.maxY))
                area.closeSubpath()
                context.fill(area, with: .linearGradient(
                    Gradient(colors: [s.color.opacity(0.35), s.color.opacity(0)]),
                    startPoint: CGPoint(x: 0, y: plot.minY), endPoint: CGPoint(x: 0, y: plot.maxY)))
                context.stroke(line, with: .color(s.color), style: StrokeStyle(lineWidth: 1.75, lineJoin: .round))
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel(series.map { s in "\(s.name) \(s.values.last.map(yLabel) ?? "no data")" }.joined(separator: ", "))
    }
}
