import Foundation

public enum SystemInfoReader {
    public static func read() -> SystemInfo {
        let p = Sysctl.value("hw.perflevel0.logicalcpu", as: Int32.self).map(Int.init) ?? 0
        let e = Sysctl.value("hw.perflevel1.logicalcpu", as: Int32.self).map(Int.init) ?? 0
        return SystemInfo(
            chipName: Sysctl.string("machdep.cpu.brand_string") ?? "Unknown CPU",
            totalMemory: Sysctl.value("hw.memsize", as: UInt64.self) ?? ProcessInfo.processInfo.physicalMemory,
            logicalCores: ProcessInfo.processInfo.processorCount,
            performanceCores: p, efficiencyCores: e,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString)
    }
}
