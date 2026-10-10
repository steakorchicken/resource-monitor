#!/usr/bin/env swift
// Draws the app icon (a dark rounded square with a gauge) and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
    a.blended(withFraction: t, of: b) ?? a
}

/// Draws the icon into a 1024×1024 coordinate space.
func drawIcon(_ ctx: CGContext) {
    // Background: macOS-style rounded square with a margin around it.
    let box = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bg = CGPath(roundedRect: box, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(bg); ctx.setFillColor(color(0x0B0E14).cgColor); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bg); ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [color(0x1B2232).cgColor, color(0x0B0E14).cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    ctx.restoreGState()
    ctx.addPath(bg); ctx.setStrokeColor(color(0x2A3347).cgColor); ctx.setLineWidth(4); ctx.strokePath()

    // Gauge geometry: 270° sweep with the gap at the bottom.
    let center = CGPoint(x: 512, y: 500)
    let radius: CGFloat = 255
    let width: CGFloat = 62
    let startDeg: CGFloat = 225, sweep: CGFloat = 270
    func angle(_ f: CGFloat) -> CGFloat { (startDeg - sweep * f) * .pi / 180 }
    func point(_ f: CGFloat, _ r: CGFloat) -> CGPoint {
        CGPoint(x: center.x + r * cos(angle(f)), y: center.y + r * sin(angle(f)))
    }
    func arc(from f0: CGFloat, to f1: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: center, radius: radius, startAngle: angle(f0), endAngle: angle(f1), clockwise: true)
        return p
    }

    // Track
    ctx.setLineCap(.round); ctx.setLineWidth(width)
    ctx.addPath(arc(from: 0, to: 1)); ctx.setStrokeColor(color(0x1F2633).cgColor); ctx.strokePath()

    // Value arc: blue → green along the arc, drawn in small segments.
    let value: CGFloat = 0.72
    let steps = 90
    for i in 0..<steps {
        let f0 = value * CGFloat(i) / CGFloat(steps), f1 = value * CGFloat(i + 1) / CGFloat(steps)
        let c = mix(color(0x4C9AFF), color(0x3DDC97), CGFloat(i) / CGFloat(steps - 1))
        ctx.setLineCap(i == 0 ? .round : .butt)
        ctx.addPath(arc(from: f0, to: min(f1 + 0.002, value))); ctx.setStrokeColor(c.cgColor); ctx.strokePath()
    }
    ctx.setLineCap(.round)
    ctx.addPath(arc(from: value - 0.0005, to: value)); ctx.setStrokeColor(color(0x3DDC97).cgColor); ctx.strokePath()

    // Tick marks inside the arc
    ctx.setLineCap(.round)
    for i in 0...10 {
        let f = CGFloat(i) / 10
        let major = i % 5 == 0
        ctx.setLineWidth(major ? 10 : 6)
        ctx.setStrokeColor(color(0x8A93A6, major ? 0.9 : 0.5).cgColor)
        ctx.move(to: point(f, radius - width / 2 - 22)); ctx.addLine(to: point(f, radius - width / 2 - (major ? 56 : 44)))
        ctx.strokePath()
    }

    // Needle with glow, then hub
    let tip = point(value, radius - 95)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 24, color: color(0x4C9AFF, 0.9).cgColor)
    ctx.setLineWidth(22); ctx.setLineCap(.round); ctx.setStrokeColor(color(0xE6EAF2).cgColor)
    ctx.move(to: center); ctx.addLine(to: tip); ctx.strokePath()
    ctx.restoreGState()
    ctx.setFillColor(color(0x4C9AFF).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))
    ctx.setFillColor(color(0x0B0E14).cgColor)
    ctx.fillEllipse(in: CGRect(x: center.x - 20, y: center.y - 20, width: 40, height: 40))
}

func renderPNG(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(ctx)
    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = fm.temporaryDirectory.appendingPathComponent("AppIcon-\(ProcessInfo.processInfo.processIdentifier).iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try renderPNG(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

let output = root.appendingPathComponent("Resources/AppIcon.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try task.run(); task.waitUntilExit()
try? fm.removeItem(at: iconset)
try renderPNG(pixels: 1024).write(to: root.appendingPathComponent("Resources/AppIcon-preview.png"))
print(task.terminationStatus == 0 ? "Wrote \(output.path)" : "iconutil failed")
