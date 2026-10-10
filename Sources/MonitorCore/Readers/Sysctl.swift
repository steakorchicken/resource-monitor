import Foundation

enum Sysctl {
    static func value<T>(_ name: String, as type: T.Type = T.self) -> T? {
        var size = MemoryLayout<T>.size
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { ptr.deallocate() }
        guard sysctlbyname(name, ptr, &size, nil, 0) == 0 else { return nil }
        return ptr.pointee
    }

    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        return String(cString: buf)
    }

    static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
}
