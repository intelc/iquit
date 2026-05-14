#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let iconPath = CommandLine.arguments.dropFirst().first ?? ".build/iQuit.app/Contents/Resources/iQuit.icns"
let outputPath = CommandLine.arguments.dropFirst().dropFirst().first ?? "docs/images/app-logo-card.png"
let outputURL = URL(fileURLWithPath: outputPath)

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let icon = NSImage(contentsOfFile: iconPath) else {
    throw NSError(
        domain: "iQuitReadmeLogo",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing icon at \(iconPath). Run Scripts/build-app.sh first."]
    )
}

let width = 520
let height = 220
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    throw NSError(domain: "iQuitReadmeLogo", code: 2)
}

rep.size = NSSize(width: width, height: height)
guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
    throw NSError(domain: "iQuitReadmeLogo", code: 3)
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color stroke: NSColor, lineWidth: CGFloat) {
    stroke.setStroke()
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
let ctx = graphics.cgContext
ctx.clear(CGRect(x: 0, y: 0, width: width, height: height))
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)

let card = CGRect(x: 8, y: 8, width: 504, height: 204)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0, 0, 0, 0.22).cgColor)
fillRounded(card, radius: 42, color: color(28, 36, 44))
ctx.restoreGState()

let gradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        color(35, 47, 56).cgColor,
        color(22, 28, 34).cgColor,
    ] as CFArray,
    locations: [0.0, 1.0]
)!
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: card, cornerWidth: 42, cornerHeight: 42, transform: nil))
ctx.clip()
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: card.minX, y: card.maxY),
    end: CGPoint(x: card.maxX, y: card.minY),
    options: []
)
ctx.setFillColor(color(41, 151, 255, 0.10).cgColor)
ctx.fillEllipse(in: CGRect(x: 52, y: 126, width: 176, height: 176))
ctx.setFillColor(color(104, 76, 231, 0.12).cgColor)
ctx.fillEllipse(in: CGRect(x: 338, y: -72, width: 220, height: 220))
ctx.restoreGState()

strokeRounded(card.insetBy(dx: 1, dy: 1), radius: 41, color: color(255, 255, 255, 0.16), lineWidth: 2)

let iconRect = CGRect(x: 76, y: 46, width: 128, height: 128)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: color(0, 0, 0, 0.28).cgColor)
icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1)
ctx.restoreGState()

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 50, weight: .bold),
    .foregroundColor: color(246, 249, 252),
]
NSString(string: "iQuit").draw(at: CGPoint(x: 242, y: 108), withAttributes: titleAttrs)

let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 20, weight: .semibold),
    .foregroundColor: color(168, 181, 194),
]
NSString(string: "tidy apps, gently").draw(at: CGPoint(x: 246, y: 76), withAttributes: subtitleAttrs)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "iQuitReadmeLogo", code: 4)
}

try data.write(to: outputURL)
print("Generated README logo: \(outputURL.path)")
