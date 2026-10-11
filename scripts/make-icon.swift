// Generates Resources/AppIcon.icns: a blue rounded square with a white speech bubble and "?".
// Usage: swift scripts/make-icon.swift   (run from the repo root)
import AppKit

let canvas: CGFloat = 1024

func drawIcon() {
    // Background squircle on Apple's standard icon grid (824pt body inside a 1024 canvas).
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 20
    shadow.set()
    NSColor(srgbRed: 0.16, green: 0.40, blue: 0.95, alpha: 1).setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.30, green: 0.56, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.11, green: 0.31, blue: 0.86, alpha: 1),
    ])!.draw(in: squircle, angle: -90)

    // Speech bubble with a tail at the bottom left.
    let bubbleRect = NSRect(x: 262, y: 350, width: 500, height: 400)
    let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: 140, yRadius: 140)
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 330, y: 420))
    tail.curve(to: NSPoint(x: 290, y: 262), controlPoint1: NSPoint(x: 335, y: 340), controlPoint2: NSPoint(x: 320, y: 290))
    tail.curve(to: NSPoint(x: 470, y: 362), controlPoint1: NSPoint(x: 370, y: 285), controlPoint2: NSPoint(x: 430, y: 320))
    tail.close()
    bubble.append(tail)

    NSGraphicsContext.saveGraphicsState()
    let bubbleShadow = NSShadow()
    bubbleShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    bubbleShadow.shadowOffset = NSSize(width: 0, height: -8)
    bubbleShadow.shadowBlurRadius = 18
    bubbleShadow.set()
    NSColor.white.setFill()
    bubble.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Question mark.
    let font = NSFont(name: "AvenirNext-Heavy", size: 320) ?? NSFont.boldSystemFont(ofSize: 320)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(srgbRed: 0.13, green: 0.36, blue: 0.92, alpha: 1),
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "?", attributes: attrs))
    let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.textPosition = CGPoint(x: bubbleRect.midX - glyphBounds.midX, y: bubbleRect.midY - glyphBounds.midY)
    CTLineDraw(line, ctx)
}

func png(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high
    ctx.cgContext.scaleBy(x: CGFloat(pixels) / canvas, y: CGFloat(pixels) / canvas)
    drawIcon()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon-\(UUID().uuidString).iconset")
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

for base in [16, 32, 128, 256, 512] {
    try png(pixels: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try png(pixels: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}

try fm.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try p.run()
p.waitUntilExit()
try png(pixels: 1024).write(to: URL(fileURLWithPath: "Resources/AppIcon.png"))
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
