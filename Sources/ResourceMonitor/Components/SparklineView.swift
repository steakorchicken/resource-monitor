import SwiftUI

/// Tiny filled line chart for sidebar rows and compact cards. Newest value is on the right.
struct SparklineView: View {
    let values: [Double]
    let color: Color
    /// Fixed scale maximum; nil auto-scales to the data.
    var maxValue: Double? = nil
    var capacity: Int = MonitorStore.historyCapacity

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let top = max(maxValue ?? (values.max() ?? 1), 0.000_001)
            let step = size.width / CGFloat(capacity - 1)
            let offset = capacity - values.count
            func point(_ i: Int) -> CGPoint {
                let y = size.height - CGFloat(min(max(values[i] / top, 0), 1)) * (size.height - 2) - 1
                return CGPoint(x: CGFloat(offset + i) * step, y: y)
            }
            var line = Path()
            line.move(to: point(0))
            for i in 1..<values.count { line.addLine(to: point(i)) }

            var fill = line
            fill.addLine(to: CGPoint(x: point(values.count - 1).x, y: size.height))
            fill.addLine(to: CGPoint(x: point(0).x, y: size.height))
            fill.closeSubpath()

            context.fill(fill, with: .linearGradient(
                Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
        }
        .drawingGroup()
    }
}
