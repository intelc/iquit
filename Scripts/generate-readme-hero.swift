#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.dropFirst().first ?? "docs/images/hero-cleanup.gif"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

let width = 960
let height = 540
let frameCount = 92
let frameDelay = 0.05
let promptStartFrame = 14
let promptCycleLength = 9

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
    let t = min(1, max(0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)
}

func mix(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

struct DemoWindow {
    let title: String
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let tint: NSColor
}

let windows: [DemoWindow] = [
    .init(title: "Mail", x: 92, y: 300, width: 274, height: 154, tint: color(55, 128, 244)),
    .init(title: "Docs", x: 242, y: 250, width: 282, height: 176, tint: color(142, 96, 255)),
    .init(title: "Chat", x: 470, y: 298, width: 244, height: 148, tint: color(47, 190, 132)),
    .init(title: "Calendar", x: 662, y: 246, width: 196, height: 150, tint: color(248, 82, 92)),
    .init(title: "Browser", x: 130, y: 120, width: 334, height: 188, tint: color(43, 158, 255)),
    .init(title: "Notes", x: 412, y: 98, width: 246, height: 178, tint: color(249, 187, 64)),
    .init(title: "Design", x: 616, y: 104, width: 244, height: 176, tint: color(32, 196, 208)),
]

func drawText(_ string: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color textColor: NSColor = .white, alpha: CGFloat = 1) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor.withAlphaComponent(alpha),
    ]
    NSString(string: string).draw(at: point, withAttributes: attrs)
}

func drawCenteredText(_ string: String, in rect: CGRect, size: CGFloat, weight: NSFont.Weight = .regular, color textColor: NSColor = .white, alpha: CGFloat = 1) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: textColor.withAlphaComponent(alpha),
    ]
    let measured = NSString(string: string).size(withAttributes: attrs)
    let point = CGPoint(
        x: rect.midX - measured.width / 2,
        y: rect.midY - measured.height / 2 - 1
    )
    NSString(string: string).draw(at: point, withAttributes: attrs)
}

func promptStart(for index: Int) -> CGFloat {
    CGFloat(promptStartFrame + index * promptCycleLength)
}

func promptWindowIndex(frameIndex: Int) -> Int? {
    let relative = frameIndex - promptStartFrame
    guard relative >= 0 else { return nil }
    let index = relative / promptCycleLength
    guard index < windows.count else { return nil }
    return index
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillRounded(_ rect: CGRect, radius: CGFloat, color fill: NSColor) {
    fill.setFill()
    roundedRect(rect, radius: radius).fill()
}

func strokeRounded(_ rect: CGRect, radius: CGFloat, color stroke: NSColor, lineWidth: CGFloat = 1) {
    stroke.setStroke()
    let path = roundedRect(rect, radius: radius)
    path.lineWidth = lineWidth
    path.stroke()
}

func drawWindow(_ window: DemoWindow, frameIndex: Int) {
    let windowIndex = windows.firstIndex { $0.title == window.title } ?? 0
    let index = CGFloat(windowIndex)
    let activeWindowIndex = promptWindowIndex(frameIndex: frameIndex)
    let isCurrentPrompt = activeWindowIndex == windowIndex
    let scan = smoothstep(7, 16, CGFloat(frameIndex))
    let clean = smoothstep(promptStart(for: windowIndex) + 5, promptStart(for: windowIndex) + 9, CGFloat(frameIndex))
    let delay = clean
    let down = 72 * delay
    let alpha = 1 - delay
    let scale = 1 - 0.10 * delay
    let center = CGPoint(x: window.x + window.width / 2, y: window.y + window.height / 2)
    let rect = CGRect(
        x: mix(window.x, center.x - window.width * scale / 2, delay),
        y: mix(window.y, center.y - window.height * scale / 2 - down, delay),
        width: window.width * scale,
        height: window.height * scale
    )

    guard alpha > 0.02 else { return }

    NSGraphicsContext.current?.cgContext.saveGState()
    NSGraphicsContext.current?.cgContext.setAlpha(alpha)
    NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -10), blur: 18, color: color(0, 0, 0, 0.18).cgColor)

    fillRounded(rect, radius: 14, color: color(31, 38, 45, 0.96))
    strokeRounded(rect, radius: 14, color: color(255, 255, 255, 0.18), lineWidth: 1)

    let titleBar = CGRect(x: rect.minX, y: rect.maxY - 34, width: rect.width, height: 34)
    fillRounded(titleBar, radius: 14, color: color(44, 52, 60, 0.96))
    window.tint.withAlphaComponent(0.88).setFill()
    NSBezierPath(ovalIn: CGRect(x: rect.minX + 14, y: rect.maxY - 23, width: 12, height: 12)).fill()
    drawText(window.title, at: CGPoint(x: rect.minX + 36, y: rect.maxY - 27), size: 13, weight: .semibold, color: color(229, 236, 244), alpha: 0.95)

    for row in 0..<3 {
        let rowWidth = rect.width * CGFloat([0.72, 0.52, 0.64][row])
        fillRounded(
            CGRect(x: rect.minX + 18, y: rect.maxY - 62 - CGFloat(row * 25), width: rowWidth, height: 10),
            radius: 5,
            color: color(120, 136, 151, 0.22)
        )
    }

    if scan > 0.05 && clean < 0.95 {
        let pulse = 0.5 + 0.5 * sin(CGFloat(frameIndex) * 0.72 + index)
        let highlight = isCurrentPrompt ? 1.0 : 0.35
        strokeRounded(
            rect.insetBy(dx: -4, dy: -4),
            radius: 18,
            color: color(41, 151, 255, (0.18 + 0.38 * pulse * scan) * highlight),
            lineWidth: 3
        )
        fillRounded(
            CGRect(x: rect.maxX - 70, y: rect.minY + 14, width: 50, height: 22),
            radius: 11,
            color: color(41, 151, 255, (isCurrentPrompt ? 0.94 : 0.40) * scan)
        )
        drawCenteredText("idle", in: CGRect(x: rect.maxX - 70, y: rect.minY + 14, width: 50, height: 22), size: 11, weight: .bold, color: .white, alpha: scan)
    }

    NSGraphicsContext.current?.cgContext.restoreGState()
}

func drawPrompt(frameIndex: Int) {
    guard let activeIndex = promptWindowIndex(frameIndex: frameIndex) else { return }
    let start = promptStart(for: activeIndex)
    let local = CGFloat(frameIndex) - start
    let appear = smoothstep(0, 2, local)
    let leave = smoothstep(6, 8, local)
    let alpha = appear * (1 - leave)
    guard alpha > 0.02 else { return }

    let app = windows[activeIndex]
    let y = mix(426, 396, appear) + 10 * leave
    let rect = CGRect(x: 472, y: y, width: 460, height: 86)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0, 0, 0, 0.25).cgColor)

    fillRounded(rect, radius: 18, color: color(29, 37, 45, 0.98))
    strokeRounded(rect, radius: 18, color: color(170, 199, 230, 0.35), lineWidth: 1.5)
    let iconRect = CGRect(x: rect.minX + 20, y: rect.minY + 20, width: 46, height: 46)
    fillRounded(iconRect, radius: 10, color: app.tint.withAlphaComponent(0.92))
    drawCenteredText(String(app.title.prefix(1)), in: iconRect, size: 18, weight: .bold, color: .white)
    drawText("\(app.title) is idle", at: CGPoint(x: rect.minX + 84, y: rect.minY + 48), size: 18, weight: .bold, color: color(244, 248, 255))
    drawText("Hide or quit it?", at: CGPoint(x: rect.minX + 84, y: rect.minY + 25), size: 14, weight: .medium, color: color(177, 190, 205))

    let hideRect = CGRect(x: rect.maxX - 190, y: rect.minY + 24, width: 86, height: 38)
    let quitRect = CGRect(x: rect.maxX - 90, y: rect.minY + 24, width: 66, height: 38)
    fillRounded(hideRect, radius: 10, color: color(24, 145, 245))
    drawCenteredText("Hide", in: hideRect, size: 15, weight: .bold)
    fillRounded(quitRect, radius: 10, color: color(245, 68, 72))
    drawCenteredText("Quit", in: quitRect, size: 15, weight: .bold)

    let progress = max(0, min(1, 1 - local / 8))
    fillRounded(CGRect(x: rect.minX + 2, y: rect.minY + 1, width: (rect.width - 4) * progress, height: 4), radius: 2, color: color(41, 151, 255, 0.95))

    let click = smoothstep(2, 5, local)
    let cursorX = mix(900, hideRect.midX + 10, click)
    let cursorY = mix(294, hideRect.midY + 4, click)
    let cursor = NSBezierPath()
    cursor.move(to: CGPoint(x: cursorX, y: cursorY))
    cursor.line(to: CGPoint(x: cursorX + 18, y: cursorY - 42))
    cursor.line(to: CGPoint(x: cursorX + 27, y: cursorY - 26))
    cursor.line(to: CGPoint(x: cursorX + 45, y: cursorY - 30))
    cursor.close()
    color(244, 248, 255).setFill()
    color(32, 40, 50, 0.55).setStroke()
    cursor.lineWidth = 2
    cursor.fill()
    cursor.stroke()

    if local >= 5 && local <= 6 {
        strokeRounded(hideRect.insetBy(dx: -4, dy: -4), radius: 12, color: color(255, 255, 255, 0.68), lineWidth: 3)
    }

    ctx.restoreGState()
}

func drawCleanState(frameIndex: Int) {
    let clean = smoothstep(promptStart(for: windows.count - 1) + 8, promptStart(for: windows.count - 1) + 14, CGFloat(frameIndex))
    guard clean > 0.02 else { return }

    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    ctx.setAlpha(clean)
    fillRounded(CGRect(x: 316, y: 190, width: 328, height: 74), radius: 18, color: color(23, 118, 84, 0.86))
    drawText("Desktop cleared", at: CGPoint(x: 402, y: 230), size: 20, weight: .bold, color: .white)
    drawText("One gentle hide at a time", at: CGPoint(x: 402, y: 207), size: 13, weight: .medium, color: color(207, 247, 225))

    color(35, 236, 132).setStroke()
    let check = NSBezierPath()
    check.lineWidth = 5
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.move(to: CGPoint(x: 344, y: 225))
    check.line(to: CGPoint(x: 358, y: 210))
    check.line(to: CGPoint(x: 384, y: 242))
    check.stroke()
    ctx.restoreGState()
}

func drawFrame(_ frameIndex: Int) throws -> CGImage {
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
        throw NSError(domain: "iQuitHero", code: 1)
    }
    rep.size = NSSize(width: width, height: height)
    guard let graphics = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "iQuitHero", code: 2)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics

    color(38, 143, 206).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    color(31, 122, 189, 0.38).setFill()
    NSBezierPath(ovalIn: CGRect(x: -160, y: -80, width: 520, height: 260)).fill()
    color(9, 101, 170, 0.18).setFill()
    NSBezierPath(ovalIn: CGRect(x: 620, y: -120, width: 520, height: 320)).fill()

    fillRounded(CGRect(x: 0, y: height - 34, width: width, height: 34), radius: 0, color: color(23, 83, 135, 0.60))
    drawText("iQuit", at: CGPoint(x: 28, y: height - 24), size: 13, weight: .bold, color: color(243, 248, 255))
    drawText("Keeping things tidy", at: CGPoint(x: 76, y: height - 24), size: 13, weight: .medium, color: color(214, 230, 245))
    drawText("Wed 5:30 PM", at: CGPoint(x: width - 118, y: height - 24), size: 13, weight: .semibold, color: color(243, 248, 255))

    for window in windows {
        drawWindow(window, frameIndex: frameIndex)
    }

    let scan = smoothstep(7, 16, CGFloat(frameIndex)) * (1 - smoothstep(promptStart(for: windows.count - 1) + 3, promptStart(for: windows.count - 1) + 8, CGFloat(frameIndex)))
    if scan > 0.01 {
        let ring = 48 + 18 * sin(CGFloat(frameIndex) * 0.7)
        color(41, 151, 255, 0.18 * scan).setFill()
        NSBezierPath(ovalIn: CGRect(x: 480 - ring, y: 270 - ring, width: ring * 2, height: ring * 2)).fill()
        drawText("finding idle windows", at: CGPoint(x: 398, y: 274), size: 16, weight: .bold, color: .white, alpha: scan)
    }

    drawPrompt(frameIndex: frameIndex)
    drawCleanState(frameIndex: frameIndex)

    NSGraphicsContext.restoreGraphicsState()

    guard let cgImage = rep.cgImage else {
        throw NSError(domain: "iQuitHero", code: 3)
    }
    return cgImage
}

guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else {
    throw NSError(domain: "iQuitHero", code: 4)
}

CGImageDestinationSetProperties(destination, [
    kCGImagePropertyGIFDictionary as String: [
        kCGImagePropertyGIFLoopCount as String: 0,
    ],
] as CFDictionary)

for frameIndex in 0..<frameCount {
    let image = try drawFrame(frameIndex)
    CGImageDestinationAddImage(destination, image, [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: frameDelay,
        ],
    ] as CFDictionary)
}

if !CGImageDestinationFinalize(destination) {
    throw NSError(domain: "iQuitHero", code: 5)
}

print("Generated hero GIF: \(outputURL.path)")
