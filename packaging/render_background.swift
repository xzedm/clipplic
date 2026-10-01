// Regenerate the committed installer artwork on macOS:
// swift packaging/render_background.swift packaging
import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "packaging")
// Leave room for Finder's title bar and optional path bar within a 320pt window.
let size = NSSize(width: 560, height: 280)

func render(scale: Int, name: String) throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width) * scale,
        pixelsHigh: Int(size.height) * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = size
    let bitmapContext = NSGraphicsContext(bitmapImageRep: bitmap)!
    let context = NSGraphicsContext(cgContext: bitmapContext.cgContext, flipped: true)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    // NSBitmapImageRep.size already applies the pixels-to-points scale.
    context.cgContext.translateBy(x: 0, y: size.height)
    context.cgContext.scaleBy(x: 1, y: -1)

    NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

    func text(_ value: String, y: CGFloat, font: NSFont, color: NSColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (value as NSString).draw(
            in: NSRect(x: 20, y: y, width: 520, height: 40),
            withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
        )
    }
    text("Install Clipplic", y: 30, font: .systemFont(ofSize: 24, weight: .semibold),
         color: NSColor(calibratedWhite: 0.16, alpha: 1))
    text("Drag Clipplic to the Applications folder", y: 66, font: .systemFont(ofSize: 14),
         color: NSColor(calibratedWhite: 0.43, alpha: 1))

    NSColor(calibratedRed: 0.42, green: 0.51, blue: 0.62, alpha: 1).setStroke()
    let arrow = NSBezierPath()
    arrow.lineWidth = 2.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: 258, y: 165))
    arrow.line(to: NSPoint(x: 302, y: 165))
    arrow.move(to: NSPoint(x: 291, y: 154))
    arrow.line(to: NSPoint(x: 302, y: 165))
    arrow.line(to: NSPoint(x: 291, y: 176))
    arrow.stroke()

    text("Once copied, open Clipplic from Applications", y: 240,
         font: .systemFont(ofSize: 12), color: NSColor(calibratedWhite: 0.48, alpha: 1))
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!
        .write(to: destination.appendingPathComponent(name))
}

try render(scale: 1, name: "background.png")
try render(scale: 2, name: "background@2x.png")
