import AppKit
import SwiftUI

/// Lazily loads and caches a process's icon; non-GUI processes get a gear symbol.
@MainActor
enum ProcessIcons {
    private static var cache: [Int32: (image: NSImage, isApp: Bool)] = [:]
    private static let fallback: NSImage = {
        let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil) ?? NSImage()
        return img
    }()

    static func icon(for pid: Int32) -> (image: NSImage, isApp: Bool) {
        if let cached = cache[pid] { return cached }
        let app = NSRunningApplication(processIdentifier: pid)
        let entry = (image: app?.icon ?? fallback, isApp: app?.icon != nil)
        cache[pid] = entry
        return entry
    }
}

struct ProcessIconView: View {
    let pid: Int32
    var body: some View {
        let entry = ProcessIcons.icon(for: pid)
        if !entry.isApp {
            Image(nsImage: entry.image).resizable().scaledToFit().foregroundStyle(Theme.textSecondary).frame(width: 16, height: 16)
        } else {
            Image(nsImage: entry.image).resizable().scaledToFit().frame(width: 16, height: 16)
        }
    }
}
