#!/usr/bin/env swift
// Pass-Y branding generator: draws the app icon (1024px) and the wordmark logo.
// Usage: swift Scripts-passy/generate_branding.swift <repo-root>
import AppKit
import CoreGraphics

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let accent = CGColor(red: 0.07, green: 0.42, blue: 0.62, alpha: 1)
let accentDark = CGColor(red: 0.04, green: 0.24, blue: 0.40, alpha: 1)

func render(width: Int, height: Int, draw: (CGContext) -> Void) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

/// A stylised "Y" whose left arm ends in a key bit, on a rounded-free square (iOS applies the mask).
func drawIcon(_ ctx: CGContext, size: CGFloat, background: Bool, foreground: CGColor) {
    if background {
        let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [accent, accentDark] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    }
    ctx.setStrokeColor(foreground)
    ctx.setFillColor(foreground)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    let lw = size * 0.11
    ctx.setLineWidth(lw)
    let cx = size / 2
    // Y: two arms meeting, then stem
    ctx.move(to: CGPoint(x: cx - size * 0.24, y: size * 0.80))
    ctx.addLine(to: CGPoint(x: cx, y: size * 0.50))
    ctx.addLine(to: CGPoint(x: cx + size * 0.24, y: size * 0.80))
    ctx.move(to: CGPoint(x: cx, y: size * 0.50))
    ctx.addLine(to: CGPoint(x: cx, y: size * 0.20))
    ctx.strokePath()
    // key teeth on stem
    ctx.move(to: CGPoint(x: cx, y: size * 0.30))
    ctx.addLine(to: CGPoint(x: cx + size * 0.12, y: size * 0.30))
    ctx.move(to: CGPoint(x: cx, y: size * 0.40))
    ctx.addLine(to: CGPoint(x: cx + size * 0.09, y: size * 0.40))
    ctx.strokePath()
}

func write(_ data: Data, _ path: String) {
    let url = URL(fileURLWithPath: root).appendingPathComponent(path)
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! data.write(to: url)
    print("wrote", path)
}

// App icon (opaque, 1024)
let icon = render(width: 1024, height: 1024) { drawIcon($0, size: 1024, background: true, foreground: .white) }
for p in ["Bitwarden/Application/Support/Assets.xcassets/AppIcon.appiconset/Icon-1024.png",
          "Bitwarden/Application/Support/Assets.xcassets/AppIcon-Dev.appiconset/Icon-1024.png",
          "Bitwarden/Application/Support/Assets.xcassets/AppIcon-Beta.appiconset/Icon-1024.png",
          "BitwardenActionExtension/Application/Support/Assets.xcassets/AppIcon.appiconset/Icon-1024.png",
          "BitwardenActionExtension/Application/Support/Assets.xcassets/AppIcon-Dev.appiconset/Icon-1024.png",
          "BitwardenActionExtension/Application/Support/Assets.xcassets/AppIcon-Beta.appiconset/Icon-1024.png"] {
    write(icon, p)
}
// Icon Composer layer (transparent foreground only)
let layer = render(width: 1024, height: 1024) { drawIcon($0, size: 1024, background: false, foreground: .white) }
write(layer, "Scripts-passy/branding/passy-layer.png")

// Wordmark: "Pass-Y" (846x132 @3x)
func wordmark(scale: CGFloat) -> Data {
    let w = Int(282 * scale), h = Int(44 * scale)
    return render(width: w, height: h) { ctx in
        let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsctx
        let font = NSFont.systemFont(ofSize: 34 * scale, weight: .bold)
        let str = NSAttributedString(string: "Pass-Y", attributes: [.font: font, .foregroundColor: NSColor.black])
        let sz = str.size()
        str.draw(at: NSPoint(x: (CGFloat(w) - sz.width) / 2, y: (CGFloat(h) - sz.height) / 2))
        NSGraphicsContext.restoreGraphicsState()
    }
}
for dir in ["Bitwarden/Application/Support/Assets.xcassets/logoBitwarden.imageset",
            "BitwardenShared/UI/Platform/Application/Support/Images.xcassets/logo.imageset"] {
    write(wordmark(scale: 1), "\(dir)/logo.png")
    write(wordmark(scale: 2), "\(dir)/logo@2x.png")
    write(wordmark(scale: 3), "\(dir)/logo@3x.png")
}
