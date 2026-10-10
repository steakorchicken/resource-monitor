import Foundation
import IOKit

public final class GPUReader {
    private let fallbackName: String

    public init(fallbackName: String = "GPU") { self.fallbackName = fallbackName }

    public func read() -> GPUSample? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS
        else { return nil }
        defer { IOObjectRelease(iterator) }

        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            defer { IOObjectRelease(entry); entry = IOIteratorNext(iterator) }
            guard let raw = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0),
                  let stats = raw.takeRetainedValue() as? [String: Any] else { continue }
            func number(_ key: String) -> Double? { (stats[key] as? NSNumber)?.doubleValue }
            guard let device = number("Device Utilization %") else { continue }

            var model = fallbackName
            if let m = IORegistryEntryCreateCFProperty(entry, "model" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() {
                if let s = m as? String { model = s }
                else if let d = m as? Data, let s = String(data: d, encoding: .utf8) { model = s.trimmingCharacters(in: .controlCharacters) }
            }
            return GPUSample(
                timestamp: Sysctl.now, model: model,
                deviceUtilization: device,
                rendererUtilization: number("Renderer Utilization %") ?? device,
                tilerUtilization: number("Tiler Utilization %") ?? 0,
                memoryInUse: UInt64(number("In use system memory") ?? 0))
        }
        return nil
    }
}
