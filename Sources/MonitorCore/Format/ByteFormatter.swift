import Foundation

public enum ByteFormatter {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// Decimal (1000-based) units like Finder and Activity Monitor, e.g. "1.5 GB".
    public static func string(_ bytes: UInt64) -> String {
        string(Double(bytes))
    }

    public static func string(_ bytes: Double) -> String {
        var value = max(0, bytes)
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        if unit == 0 { return "\(Int(value)) B" }
        return String(format: value < 10 ? "%.2f %@" : (value < 100 ? "%.1f %@" : "%.0f %@"), value, units[unit])
    }
}
