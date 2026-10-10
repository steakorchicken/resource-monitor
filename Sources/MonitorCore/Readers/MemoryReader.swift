import Foundation
import Darwin

public final class MemoryReader {
    private let total: UInt64
    private let pageSize: UInt64

    public init() {
        total = Sysctl.value("hw.memsize", as: UInt64.self) ?? ProcessInfo.processInfo.physicalMemory
        pageSize = UInt64(vm_kernel_page_size)
    }

    public func read() -> MemorySample? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pages = MemoryPages(
            internalPages: UInt64(stats.internal_page_count),
            purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count),
            wired: UInt64(stats.wire_count),
            compressor: UInt64(stats.compressor_page_count))
        let m = MemoryMath.compose(pages: pages, pageSize: pageSize, total: total)

        let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self)
        let level = Sysctl.value("kern.memorystatus_vm_pressure_level", as: Int32.self) ?? 1

        return MemorySample(
            timestamp: Sysctl.now, total: total,
            app: m.app, wired: m.wired, compressed: m.compressed, cached: m.cached,
            free: m.free, used: m.used, available: m.available,
            swapTotal: swap?.xsu_total ?? 0, swapUsed: swap?.xsu_used ?? 0,
            pressure: MemoryPressure(level: level))
    }
}
