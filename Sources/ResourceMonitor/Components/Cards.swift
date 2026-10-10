import SwiftUI

struct SectionCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct DetailHeader: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 4, height: 22)
                Text(title).font(.system(size: 24, weight: .semibold)).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
        }
    }
}

struct StatTile: View {
    let label: String
    let value: String
    var detail: String? = nil
    var tint: Color = Theme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let detail {
                Text(detail).font(.system(size: 11)).foregroundStyle(Theme.textSecondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .card()
    }
}

struct TileGrid<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) { content }
    }
}

/// Horizontal fill bar. With `colorByLevel` it goes green → yellow → red as it fills.
struct UsageBar: View {
    let fraction: Double
    var tint: Color = Theme.disk
    var colorByLevel = false
    var height: CGFloat = 8

    private var fill: Color {
        guard colorByLevel else { return tint }
        return fraction >= 0.9 ? Theme.red : (fraction >= 0.75 ? Theme.yellow : tint)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardBorder)
                Capsule().fill(fill).frame(width: max(height, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: height)
    }
}

/// Circular gauge with the value in the middle.
struct RingGauge: View {
    let fraction: Double
    let valueText: String
    let caption: String
    let tint: Color
    var size: CGFloat = 130

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardBorder, lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(AngularGradient(colors: [tint.opacity(0.55), tint], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(fraction, 0.01))),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(valueText).font(.system(size: 26, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.textPrimary)
                Text(caption).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: size, height: size)
        .padding(8)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 10, height: 10)
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 4)
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.system(size: 12))
    }
}

/// Stacked horizontal bar made of proportional segments.
struct SegmentedBar: View {
    struct Segment: Identifiable {
        var id: String { label }
        let label: String
        let value: Double
        let color: Color
    }
    let segments: [Segment]
    var height: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let total = max(segments.map(\.value).reduce(0, +), 0.000_001)
            HStack(spacing: 1) {
                ForEach(segments) { seg in
                    Rectangle().fill(seg.color)
                        .frame(width: max(0, geo.size.width * seg.value / total - 1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .frame(height: height)
    }
}

/// Memory pressure as three lit/dim lamps.
struct PressureGauge: View {
    let level: Int   // 1 normal, 2 warning, 4 critical
    var body: some View {
        let active = level >= 4 ? 2 : (level >= 2 ? 1 : 0)
        let colors = [Theme.green, Theme.yellow, Theme.red]
        let names = ["Normal", "Warning", "Critical"]
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(colors[i].opacity(i == active ? 1 : 0.18)).frame(height: 10)
                }
            }
            Text(names[active]).font(.system(size: 15, weight: .semibold)).foregroundStyle(colors[active])
        }
    }
}
