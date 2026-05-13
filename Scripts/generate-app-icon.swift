#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? ".build/iQuit.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let workURL = outputURL
    .deletingLastPathComponent()
    .appendingPathComponent("iQuit.iconset", isDirectory: true)

let fileManager = FileManager.default
try? fileManager.removeItem(at: workURL)
try fileManager.createDirectory(at: workURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconVariant {
    let filename: String
    let pixels: Int
}

let variants = [
    IconVariant(filename: "icon_16x16.png", pixels: 16),
    IconVariant(filename: "icon_16x16@2x.png", pixels: 32),
    IconVariant(filename: "icon_32x32.png", pixels: 32),
    IconVariant(filename: "icon_32x32@2x.png", pixels: 64),
    IconVariant(filename: "icon_128x128.png", pixels: 128),
    IconVariant(filename: "icon_128x128@2x.png", pixels: 256),
    IconVariant(filename: "icon_256x256.png", pixels: 256),
    IconVariant(filename: "icon_256x256@2x.png", pixels: 512),
    IconVariant(filename: "icon_512x512.png", pixels: 512),
    IconVariant(filename: "icon_512x512@2x.png", pixels: 1024),
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(pixels: Int) throws -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "iQuitIcon", code: 1)
    }

    rep.size = NSSize(width: pixels, height: pixels)
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "iQuitIcon", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    let ctx = graphics.cgContext
    let size = CGFloat(pixels)
    let scale = size / 1024
    ctx.setShouldAntialias(true)
    ctx.setAllowsAntialiasing(true)
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let cornerRadius = 228 * scale
    let rect = CGRect(x: 42 * scale, y: 42 * scale, width: 940 * scale, height: 940 * scale)
    let basePath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(basePath)
    ctx.clip()

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            color(9, 147, 255).cgColor,
            color(65, 96, 255).cgColor,
            color(104, 76, 231).cgColor,
        ] as CFArray,
        locations: [0.0, 0.56, 1.0]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: 160 * scale, y: 930 * scale),
        end: CGPoint(x: 850 * scale, y: 80 * scale),
        options: []
    )

    ctx.setFillColor(color(255, 255, 255, 0.16).cgColor)
    ctx.fillEllipse(in: CGRect(x: 72 * scale, y: 670 * scale, width: 350 * scale, height: 350 * scale))

    ctx.setFillColor(color(20, 32, 80, 0.20).cgColor)
    ctx.fillEllipse(in: CGRect(x: 600 * scale, y: -80 * scale, width: 420 * scale, height: 420 * scale))
    ctx.restoreGState()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18 * scale), blur: 34 * scale, color: color(0, 0, 0, 0.22).cgColor)
    ctx.setFillColor(color(238, 247, 255).cgColor)
    ctx.fillEllipse(in: CGRect(x: 278 * scale, y: 238 * scale, width: 420 * scale, height: 420 * scale))
    ctx.restoreGState()

    ctx.setFillColor(color(42, 105, 245).cgColor)
    ctx.fillEllipse(in: CGRect(x: 424 * scale, y: 318 * scale, width: 390 * scale, height: 390 * scale))

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * scale), blur: 18 * scale, color: color(0, 0, 0, 0.18).cgColor)
    ctx.setStrokeColor(color(204, 246, 255, 0.94).cgColor)
    ctx.setLineWidth(54 * scale)
    ctx.setLineCap(.round)
    let ringRect = CGRect(x: 610 * scale, y: 240 * scale, width: 214 * scale, height: 214 * scale)
    ctx.strokeEllipse(in: ringRect)
    ctx.move(to: CGPoint(x: 717 * scale, y: 440 * scale))
    ctx.addLine(to: CGPoint(x: 717 * scale, y: 548 * scale))
    ctx.strokePath()
    ctx.restoreGState()

    let zColor = color(224, 248, 255, 0.95)
    let zPositions: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("z", 616, 700, 86),
        ("z", 704, 762, 64),
        ("z", 782, 804, 48),
    ]
    for (text, x, y, fontSize) in zPositions {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize * scale, weight: .bold),
            .foregroundColor: zColor,
        ]
        NSString(string: text).draw(
            at: CGPoint(x: x * scale, y: y * scale),
            withAttributes: attrs
        )
    }

    ctx.addPath(basePath)
    ctx.setStrokeColor(color(255, 255, 255, 0.22).cgColor)
    ctx.setLineWidth(3 * scale)
    ctx.strokePath()

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iQuitIcon", code: 3)
    }
    return data
}

for variant in variants {
    let data = try drawIcon(pixels: variant.pixels)
    try data.write(to: workURL.appendingPathComponent(variant.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", workURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "iQuitIcon", code: Int(process.terminationStatus))
}

try? fileManager.removeItem(at: workURL)

print("Generated icon: \(outputURL.path)")
