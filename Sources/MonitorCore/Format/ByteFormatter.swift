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

    /// Binary (1024-based) GB like Activity Monitor uses for RAM, e.g. "5.69 GB".
    public static func memoryString(_ bytes: UInt64) -> String {
        let value = Double(bytes)
        let gb = value / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        return String(format: "%.0f MB", value / 1_048_576)
    }
}
