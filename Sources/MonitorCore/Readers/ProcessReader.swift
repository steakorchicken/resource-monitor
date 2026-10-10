import Foundation
import Darwin

public final class ProcessReader {
    private struct Previous { var cpuNanos: Double; var readBytes: UInt64; var writeBytes: UInt64 }
    private struct Identity { var startSeconds: UInt64; var name: String }

    private var previous: [Int32: Previous] = [:]
    private var previousTime: TimeInterval?
    private var identities: [Int32: Identity] = [:]
    private var userNames: [UInt32: String] = [:]
    private let nanosPerTick: Double

    public init() {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        nanosPerTick = tb.denom == 0 ? 1 : Double(tb.numer) / Double(tb.denom)
    }

    private func listPIDs() -> [Int32] {
        let estimate = Int(proc_listallpids(nil, 0))
        guard estimate > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: estimate + 64)
        let written = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size)))
        guard written > 0 else { return [] }
        // proc_listallpids reports a count of pids (older docs say bytes); cap either way.
        let n = written <= pids.count ? written : written / MemoryLayout<Int32>.size
        return Array(pids.prefix(n))
    }

    private func userName(_ uid: UInt32) -> String? {
        if let cached = userNames[uid] { return cached }
        guard let pw = getpwuid(uid) else { return nil }
        let name = String(cString: pw.pointee.pw_name)
        userNames[uid] = name
        return name
    }

    private func executableName(pid: Int32) -> String? {
        var path = [CChar](repeating: 0, count: 4096)
        if proc_pidpath(pid, &path, UInt32(path.count)) > 0 {
            let last = (String(cString: path) as NSString).lastPathComponent
            if !last.isEmpty { return last }
        }
        var short = [CChar](repeating: 0, count: 64)
        if proc_name(pid, &short, UInt32(short.count)) > 0 { return String(cString: short) }
        return nil
    }

    /// Returns nil only if the process list itself is unavailable.
    public func read() -> ProcessSnapshot? {
        let pids = listPIDs()
        guard !pids.isEmpty else { return nil }
        let now = Sysctl.now
        let wallNanos = previousTime.map { (now - $0) * 1e9 } ?? 0

        var rows: [ProcessInfoRow] = []
        rows.reserveCapacity(pids.count)
        var newPrevious: [Int32: Previous] = [:]
        newPrevious.reserveCapacity(pids.count)
        var threadTotal = 0

        for pid in pids {
            var bsd = proc_bsdinfo()
            let bsdOK = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, Int32(MemoryLayout<proc_bsdinfo>.size)) == Int32(MemoryLayout<proc_bsdinfo>.size)
            let start = bsdOK ? UInt64(bsd.pbi_start_tvsec) : 0

            // Name is cached per pid, refreshed if the pid was reused by a new process.
            var name: String
            if let id = identities[pid], id.startSeconds == start {
                name = id.name
            } else {
                name = executableName(pid: pid) ?? "(\(pid))"
                identities[pid] = Identity(startSeconds: start, name: name)
            }

            var row = ProcessInfoRow(pid: pid, name: name)
            if bsdOK {
                row.uid = bsd.pbi_uid
                row.user = userName(bsd.pbi_uid)
            }

            var task = proc_taskinfo()
            let taskOK = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) == Int32(MemoryLayout<proc_taskinfo>.size)

            var usage = rusage_info_v4()
            let usageOK = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            } == 0

            if taskOK {
                let cpuNanos = Double(task.pti_total_user &+ task.pti_total_system) * nanosPerTick
                row.threads = Int(task.pti_threadnum)
                threadTotal += Int(task.pti_threadnum)
                if let prev = previous[pid], wallNanos > 0 {
                    row.cpuPercent = ProcessMath.cpuPercent(prevCPUNanos: prev.cpuNanos, curCPUNanos: cpuNanos, wallNanos: wallNanos)
                } else {
                    row.cpuPercent = 0
                }
                newPrevious[pid] = Previous(cpuNanos: cpuNanos,
                                            readBytes: usageOK ? usage.ri_diskio_bytesread : 0,
                                            writeBytes: usageOK ? usage.ri_diskio_byteswritten : 0)
            }
            if usageOK {
                row.memoryBytes = usage.ri_phys_footprint
                if let prev = previous[pid], wallNanos > 0 {
                    let secs = wallNanos / 1e9
                    row.diskReadBytesPerSecond = CounterMath.rate(delta: CounterMath.delta(prev: prev.readBytes, cur: usage.ri_diskio_bytesread), seconds: secs)
                    row.diskWriteBytesPerSecond = CounterMath.rate(delta: CounterMath.delta(prev: prev.writeBytes, cur: usage.ri_diskio_byteswritten), seconds: secs)
                } else {
                    row.diskReadBytesPerSecond = 0
                    row.diskWriteBytesPerSecond = 0
                }
            }
            rows.append(row)
        }

        previous = newPrevious
        previousTime = now
        let alive = Set(pids)
        identities = identities.filter { alive.contains($0.key) }
        return ProcessSnapshot(rows: rows, threadCount: threadTotal)
    }
}
