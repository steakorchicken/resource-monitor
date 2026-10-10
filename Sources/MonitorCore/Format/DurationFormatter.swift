import Foundation

public enum DurationFormatter {
    /// "3d 4:05:09" for uptime-style durations; days omitted when zero.
    public static func uptime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let days = total / 86_400
        let hours = (total % 86_400) / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let clock = String(format: "%d:%02d:%02d", hours, minutes, secs)
        return days > 0 ? "\(days)d \(clock)" : clock
    }

    /// "2h 15m" style for time remaining.
    public static func short(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }
}
