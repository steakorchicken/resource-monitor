import Foundation
import IOKit

/// Minimal read-only client for the AppleSMC IOKit service (no private frameworks).
final class SMC {
    private var connection: io_connect_t = 0

    // SMCKeyData_t is 80 bytes; offsets of the fields we use:
    private enum Offset {
        static let key = 0, dataSize = 28, dataType = 32, result = 40, command = 42, index = 44, bytes = 48
        static let size = 80
    }
    private enum Command: UInt8 { case readBytes = 5, readIndex = 8, readKeyInfo = 9 }

    init?() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &connection) == KERN_SUCCESS else { return nil }
    }

    deinit { if connection != 0 { IOServiceClose(connection) } }

    static func code(_ s: String) -> UInt32 { s.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) } }
    static func string(_ c: UInt32) -> String {
        String(bytes: [UInt8(c >> 24 & 0xFF), UInt8(c >> 16 & 0xFF), UInt8(c >> 8 & 0xFF), UInt8(c & 0xFF)], encoding: .ascii) ?? ""
    }

    private func call(key: UInt32 = 0, command: Command, dataSize: UInt32 = 0, index: UInt32 = 0) -> [UInt8]? {
        var input = [UInt8](repeating: 0, count: Offset.size)
        var output = [UInt8](repeating: 0, count: Offset.size)
        input.withUnsafeMutableBytes {
            $0.storeBytes(of: key, toByteOffset: Offset.key, as: UInt32.self)
            $0.storeBytes(of: dataSize, toByteOffset: Offset.dataSize, as: UInt32.self)
            $0.storeBytes(of: command.rawValue, toByteOffset: Offset.command, as: UInt8.self)
            $0.storeBytes(of: index, toByteOffset: Offset.index, as: UInt32.self)
        }
        var outSize = Offset.size
        let kr = IOConnectCallStructMethod(connection, 2, input, Offset.size, &output, &outSize)
        guard kr == KERN_SUCCESS, output[Offset.result] == 0 else { return nil }
        return output
    }

    private func u32(_ buf: [UInt8], _ offset: Int) -> UInt32 {
        buf.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
    }

    func key(at index: Int) -> String? {
        guard let out = call(command: .readIndex, index: UInt32(index)) else { return nil }
        let s = SMC.string(u32(out, Offset.key))
        return s.isEmpty ? nil : s
    }

    func keyCount() -> Int {
        guard let v = readNumber("#KEY") else { return 0 }
        return Int(v)
    }

    struct Raw { var type: String; var bytes: [UInt8] }

    func readRaw(_ key: String) -> Raw? {
        let code = SMC.code(key)
        guard let info = call(key: code, command: .readKeyInfo) else { return nil }
        let size = u32(info, Offset.dataSize)
        let type = SMC.string(u32(info, Offset.dataType))
        guard size > 0, size <= 32, let out = call(key: code, command: .readBytes, dataSize: size) else { return nil }
        return Raw(type: type, bytes: Array(out[Offset.bytes..<(Offset.bytes + Int(size))]))
    }

    func readNumber(_ key: String) -> Double? {
        guard let raw = readRaw(key) else { return nil }
        return SMC.decode(raw)
    }

    static func decode(_ raw: Raw) -> Double? {
        let b = raw.bytes
        switch raw.type {
        case "flt " where b.count == 4:
            return Double(Float(bitPattern: UInt32(b[0]) | UInt32(b[1]) << 8 | UInt32(b[2]) << 16 | UInt32(b[3]) << 24))
        case "ui8 " where b.count == 1: return Double(b[0])
        case "ui16" where b.count == 2: return Double(UInt16(b[0]) << 8 | UInt16(b[1]))
        case "ui32" where b.count == 4: return Double(UInt32(b[0]) << 24 | UInt32(b[1]) << 16 | UInt32(b[2]) << 8 | UInt32(b[3]))
        case "sp78" where b.count == 2: return Double(Int16(bitPattern: UInt16(b[0]) << 8 | UInt16(b[1]))) / 256
        case "fpe2" where b.count == 2: return Double(UInt16(b[0]) << 8 | UInt16(b[1])) / 4
        default: return nil
        }
    }
}
