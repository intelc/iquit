#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? ".build/iQuit.icns"
let sourcePath = CommandLine.arguments.dropFirst().dropFirst().first ?? "docs/images/app-icon-source.png"
let outputURL = URL(fileURLWithPath: outputPath)
let sourceURL = URL(fileURLWithPath: sourcePath)
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

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let sourceCG = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    throw NSError(
        domain: "iQuitIcon",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Missing source icon at \(sourceURL.path)"]
    )
}

guard let sourceTIFF = sourceImage.tiffRepresentation,
      let sourceRep = NSBitmapImageRep(data: sourceTIFF)
else {
    throw NSError(domain: "iQuitIcon", code: 2)
}

func cropRect(for rep: NSBitmapImageRep) -> CGRect {
    var minX = rep.pixelsWide
    var minY = rep.pixelsHigh
    var maxX = 0
    var maxY = 0

    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            guard let sampled = rep.colorAt(x: x, y: y),
                  let rgb = sampled.usingColorSpace(.deviceRGB)
            else { continue }
            let isCanvas = rgb.alphaComponent > 0.95
                && rgb.redComponent > 0.94
                && rgb.greenComponent > 0.94
                && rgb.blueComponent > 0.94
            if !isCanvas {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard minX < maxX, minY < maxY else {
        let side = min(rep.pixelsWide, rep.pixelsHigh)
        return CGRect(
            x: (rep.pixelsWide - side) / 2,
            y: (rep.pixelsHigh - side) / 2,
            width: side,
            height: side
        )
    }

    let padding = Int(Double(max(maxX - minX, maxY - minY)) * 0.03)
    minX = max(0, minX - padding)
    minY = max(0, minY - padding)
    maxX = min(rep.pixelsWide - 1, maxX + padding)
    maxY = min(rep.pixelsHigh - 1, maxY + padding)

    let contentWidth = maxX - minX + 1
    let contentHeight = maxY - minY + 1
    let side = max(contentWidth, contentHeight)
    let centerX = minX + contentWidth / 2
    let centerY = minY + contentHeight / 2
    let originX = min(max(0, centerX - side / 2), max(0, rep.pixelsWide - side))
    let originY = min(max(0, centerY - side / 2), max(0, rep.pixelsHigh - side))
    return CGRect(x: originX, y: originY, width: side, height: side)
}

let sourceCrop = cropRect(for: sourceRep)

func renderIcon(pixels: Int) throws -> Data {
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
        throw NSError(domain: "iQuitIcon", code: 2)
    }

    rep.size = NSSize(width: pixels, height: pixels)
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "iQuitIcon", code: 3)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high

    let rect = CGRect(x: 0, y: 0, width: pixels, height: pixels)
    graphics.cgContext.clear(rect)
    if let cropped = sourceCG.cropping(to: sourceCrop) {
        graphics.cgContext.saveGState()
        let radius = CGFloat(pixels) * 0.20
        graphics.cgContext.addPath(CGPath(
            roundedRect: rect.insetBy(dx: CGFloat(pixels) * 0.04, dy: CGFloat(pixels) * 0.04),
            cornerWidth: radius,
            cornerHeight: radius,
            transform: nil
        ))
        graphics.cgContext.clip()
        graphics.cgContext.draw(cropped, in: rect)
        graphics.cgContext.restoreGState()
    } else {
        graphics.cgContext.draw(sourceCG, in: rect)
    }

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "iQuitIcon", code: 4)
    }
    return data
}

for variant in variants {
    let data = try renderIcon(pixels: variant.pixels)
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
