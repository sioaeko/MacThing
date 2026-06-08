import AppKit
import Foundation

guard CommandLine.arguments.count == 2 || CommandLine.arguments.count == 3 else {
    fputs("usage: swift Scripts/GenerateAppIcon.swift <output.iconset> [output.icns]\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let fileManager = FileManager.default
try? fileManager.removeItem(at: outputURL)
try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true)

let iconFiles: [(points: Int, scale: Int, name: String)] = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png")
]

for file in iconFiles {
    let pixels = file.points * file.scale
    let data = try renderIconPNG(pixels: pixels)
    try data.write(to: outputURL.appendingPathComponent(file.name))
}

if CommandLine.arguments.count == 3 {
    try writeICNS(
        from: outputURL,
        to: URL(fileURLWithPath: CommandLine.arguments[2])
    )
}

func renderIconPNG(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw IconError.bitmapCreationFailed
    }

    bitmap.size = NSSize(width: pixels, height: pixels)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError.graphicsContextCreationFailed
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncodingFailed
    }

    return data
}

func writeICNS(from iconsetURL: URL, to icnsURL: URL) throws {
    let entries: [(type: String, fileName: String)] = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png")
    ]

    var body = Data()

    for entry in entries {
        guard let typeData = entry.type.data(using: .ascii), typeData.count == 4 else {
            throw IconError.invalidICNSType(entry.type)
        }

        let pngData = try Data(contentsOf: iconsetURL.appendingPathComponent(entry.fileName))
        body.append(typeData)
        body.appendUInt32BE(UInt32(pngData.count + 8))
        body.append(pngData)
    }

    var icns = Data()
    icns.append(Data("icns".utf8))
    icns.appendUInt32BE(UInt32(body.count + 8))
    icns.append(body)
    try icns.write(to: icnsURL)
}

func drawIcon(in bounds: NSRect) {
    let s = min(bounds.width, bounds.height)

    NSColor.clear.setFill()
    bounds.fill()

    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.018)
    shadow.shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.30)

    NSGraphicsContext.saveGraphicsState()
    shadow.set()

    let baseRect = bounds.insetBy(dx: s * 0.065, dy: s * 0.065)
    let basePath = NSBezierPath(
        roundedRect: baseRect,
        xRadius: s * 0.185,
        yRadius: s * 0.185
    )

    let baseGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.075, alpha: 1.0),
        NSColor(calibratedRed: 0.060, green: 0.185, blue: 0.195, alpha: 1.0),
        NSColor(calibratedRed: 0.025, green: 0.035, blue: 0.050, alpha: 1.0)
    ])
    baseGradient?.draw(in: basePath, angle: -35)
    NSGraphicsContext.restoreGraphicsState()

    let highlightPath = NSBezierPath(
        roundedRect: baseRect.insetBy(dx: s * 0.025, dy: s * 0.025),
        xRadius: s * 0.16,
        yRadius: s * 0.16
    )
    NSColor(calibratedWhite: 1.0, alpha: 0.10).setStroke()
    highlightPath.lineWidth = max(1.0, s * 0.012)
    highlightPath.stroke()

    drawIndexBars(size: s)
    drawMagnifier(size: s)
    drawSpark(size: s)
}

func drawIndexBars(size s: CGFloat) {
    let bars: [(x: CGFloat, y: CGFloat, width: CGFloat, color: NSColor)] = [
        (0.305, 0.635, 0.230, NSColor(calibratedRed: 0.56, green: 0.93, blue: 0.91, alpha: 1.0)),
        (0.305, 0.555, 0.305, NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.36, alpha: 1.0)),
        (0.305, 0.475, 0.190, NSColor(calibratedRed: 0.74, green: 0.86, blue: 1.00, alpha: 1.0))
    ]

    for bar in bars {
        let rect = NSRect(
            x: s * bar.x,
            y: s * bar.y,
            width: s * bar.width,
            height: max(2.0, s * 0.028)
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.014, yRadius: s * 0.014)
        bar.color.setFill()
        path.fill()
    }
}

func drawMagnifier(size s: CGFloat) {
    let ringRect = NSRect(x: s * 0.205, y: s * 0.345, width: s * 0.455, height: s * 0.455)
    let ring = NSBezierPath(ovalIn: ringRect)
    ring.lineWidth = max(2.0, s * 0.060)
    NSColor(calibratedWhite: 0.98, alpha: 0.95).setStroke()
    ring.stroke()

    let innerRing = NSBezierPath(ovalIn: ringRect.insetBy(dx: s * 0.070, dy: s * 0.070))
    innerRing.lineWidth = max(1.0, s * 0.012)
    NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
    innerRing.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: s * 0.615, y: s * 0.355))
    handle.line(to: NSPoint(x: s * 0.805, y: s * 0.165))
    handle.lineWidth = max(3.0, s * 0.075)
    handle.lineCapStyle = .round
    NSColor(calibratedWhite: 0.98, alpha: 0.95).setStroke()
    handle.stroke()

    let handleCap = NSBezierPath()
    handleCap.move(to: NSPoint(x: s * 0.615, y: s * 0.355))
    handleCap.line(to: NSPoint(x: s * 0.805, y: s * 0.165))
    handleCap.lineWidth = max(1.0, s * 0.020)
    handleCap.lineCapStyle = .round
    NSColor(calibratedRed: 0.58, green: 0.94, blue: 0.92, alpha: 0.45).setStroke()
    handleCap.stroke()
}

func drawSpark(size s: CGFloat) {
    let spark = NSBezierPath()
    spark.move(to: NSPoint(x: s * 0.705, y: s * 0.735))
    spark.line(to: NSPoint(x: s * 0.735, y: s * 0.650))
    spark.line(to: NSPoint(x: s * 0.820, y: s * 0.620))
    spark.line(to: NSPoint(x: s * 0.735, y: s * 0.590))
    spark.line(to: NSPoint(x: s * 0.705, y: s * 0.505))
    spark.line(to: NSPoint(x: s * 0.675, y: s * 0.590))
    spark.line(to: NSPoint(x: s * 0.590, y: s * 0.620))
    spark.line(to: NSPoint(x: s * 0.675, y: s * 0.650))
    spark.close()

    NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.33, alpha: 0.98).setFill()
    spark.fill()
}

enum IconError: Error {
    case bitmapCreationFailed
    case graphicsContextCreationFailed
    case pngEncodingFailed
    case invalidICNSType(String)
}

extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}
