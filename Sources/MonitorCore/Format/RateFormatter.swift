import Foundation

public enum RateFormatter {
    /// Bytes per second, e.g. "2.3 MB/s".
    public static func string(bytesPerSecond: Double) -> String {
        ByteFormatter.string(bytesPerSecond) + "/s"
    }

    /// Percentage with no decimals, e.g. "23 %".
    public static func percent(_ value: Double) -> String {
        String(format: "%.0f %%", value)
    }
}
