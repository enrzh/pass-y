#!/usr/bin/swift
// Pass-Y logo generator. One geometry (1024 grid), rendered as SVG + PNG + PDF; writes all app icon assets.
// A "Y" cut like a key: two arms meeting in a keyhole, a stem with two key teeth. Flat, two colors.
// Usage: swift Scripts-passy/generate_logo.swift <repo-root>
import AppKit
import CoreGraphics

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default

struct Palette { let bg: (CGFloat, CGFloat, CGFloat)?; let fg: (CGFloat, CGFloat, CGFloat); let hole: (CGFloat, CGFloat, CGFloat) }
let light = Palette(bg: (0.043, 0.373, 0.839), fg: (1, 1, 1), hole: (0.043, 0.373, 0.839))   // #0B5FD6 / white
let dark = Palette(bg: (0.039, 0.082, 0.165), fg: (0.376, 0.671, 1.0), hole: (0.039, 0.082, 0.165)) // navy / light blue
let tinted = Palette(bg: (0, 0, 0), fg: (1, 1, 1), hole: (0, 0, 0))
let markOnly = Palette(bg: nil, fg: (0.043, 0.373, 0.839), hole: (0, 0, 0)) // template/wordmark use (hole punched)

func col(_ c: (CGFloat, CGFloat, CGFloat)) -> CGColor { CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1) }

/// Draws the mark on a 1024 grid scaled into `size` (y axis flipped to match SVG).
func drawMark(_ ctx: CGContext, size: CGFloat, palette: Palette, punchHole: Bool = false) {
    let k = size / 1024
    ctx.saveGState()
    ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: k, y: -k)
    if let bg = palette.bg { ctx.setFillColor(col(bg)); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024)) }
    ctx.setStrokeColor(col(palette.fg)); ctx.setFillColor(col(palette.fg))
    ctx.setLineWidth(118); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 290, y: 232)); ctx.addLine(to: CGPoint(x: 512, y: 520)); ctx.addLine(to: CGPoint(x: 734, y: 232))
    ctx.move(to: CGPoint(x: 512, y: 520)); ctx.addLine(to: CGPoint(x: 512, y: 800))
    ctx.strokePath()
    // key teeth
    ctx.fill(CGRect(x: 512, y: 668, width: 118, height: 66))
    ctx.fill(CGRect(x: 512, y: 760, width: 86, height: 66))
    // keyhole at the fork
    if punchHole { ctx.setBlendMode(.clear) } else { ctx.setFillColor(col(palette.hole)) }
    ctx.fillEllipse(in: CGRect(x: 512 - 46, y: 520 - 46, width: 92, height: 92))
    ctx.setBlendMode(.normal)
    ctx.restoreGState()
}

func png(size: Int, palette: Palette, punchHole: Bool = false) -> Data {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawMark(ctx, size: CGFloat(size), palette: palette, punchHole: punchHole)
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

func pdf(palette: Palette) -> Data {
    let data = NSMutableData()
    var box = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    let c = CGContext(consumer: CGDataConsumer(data: data)!, mediaBox: &box, nil)!
    c.beginPDFPage(nil); drawMark(c, size: 1024, palette: palette, punchHole: false); c.endPDFPage(); c.closePDF()
    return data as Data
}

func write(_ d: Data, _ rel: String) {
    let u = URL(fileURLWithPath: root).appendingPathComponent(rel)
    try? fm.createDirectory(at: u.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! d.write(to: u)
}
func writeText(_ s: String, _ rel: String) { write(s.data(using: .utf8)!, rel) }

// --- SVG source (same geometry) ---
func hex(_ c: (CGFloat, CGFloat, CGFloat)) -> String { String(format: "#%02X%02X%02X", Int(c.0 * 255), Int(c.1 * 255), Int(c.2 * 255)) }
func svg(_ p: Palette) -> String {
    let bgRect = p.bg.map { "<rect width=\"1024\" height=\"1024\" fill=\"\(hex($0))\"/>" } ?? ""
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
      \(bgRect)
      <g fill="none" stroke="\(hex(p.fg))" stroke-width="118" stroke-linecap="round" stroke-linejoin="round">
        <path d="M290 232 L512 520 L734 232 M512 520 L512 800"/>
      </g>
      <g fill="\(hex(p.fg))"><rect x="512" y="668" width="118" height="66"/><rect x="512" y="760" width="86" height="66"/></g>
      <circle cx="512" cy="520" r="46" fill="\(hex(p.hole))"/>
    </svg>
    """
}
writeText(svg(light), "Branding/passy-logo.svg")
writeText(svg(dark), "Branding/passy-logo-dark.svg")
writeText(svg(tinted), "Branding/passy-logo-tinted.svg")
write(png(size: 1024, palette: light), "Branding/passy-logo.png")
write(png(size: 512, palette: light), "Branding/passy-logo-512.png")

// --- iOS 18 style app icon sets (any / dark / tinted) ---
let contents = """
{
  "images" : [
    { "filename" : "Icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ], "filename" : "Icon-1024-dark.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "appearances" : [ { "appearance" : "luminosity", "value" : "tinted" } ], "filename" : "Icon-1024-tinted.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
for base in ["Bitwarden/Application/Support/Assets.xcassets", "BitwardenActionExtension/Application/Support/Assets.xcassets"] {
    for set in ["AppIcon", "AppIcon-Dev", "AppIcon-Beta"] {
        let d = "\(base)/\(set).appiconset"
        write(png(size: 1024, palette: light), "\(d)/Icon-1024.png")
        write(png(size: 1024, palette: dark), "\(d)/Icon-1024-dark.png")
        write(png(size: 1024, palette: tinted), "\(d)/Icon-1024-tinted.png")
        writeText(contents, "\(d)/Contents.json")
    }
}
// --- watch app + widget icons (opaque square, light variant) ---
for set in ["AppIcon", "AppIcon-Dev", "AppIcon-Beta"] {
    write(png(size: 1024, palette: light), "BitwardenWatchApp/Assets.xcassets/\(set).appiconset/Icon-1024.png")
}
write(png(size: 1024, palette: light), "BitwardenWatchWidgetExtension/Assets.xcassets/AppIcon.appiconset/Icon-1024.png")
write(png(size: 50, palette: light), "BitwardenWatchWidgetExtension/Icon-50.png")
write(png(size: 100, palette: light), "BitwardenWatchApp/Assets.xcassets/ComplicationIcon.imageset/Icon-100.png")
write(png(size: 100, palette: light), "BitwardenWatchWidgetExtension/Assets.xcassets/ComplicationIcon.imageset/Icon-100.png")
for f in ["BitwardenWatchApp/Assets.xcassets/BitwardenImagetype.imageset/passy-logo-1.pdf",
          "BitwardenWatchApp/Assets.xcassets/BitwardenImagetype.imageset/passy-logo-2.pdf",
          "BitwardenWatchApp/Assets.xcassets/BitwardenImagetype.imageset/passy-logo-3.pdf",
          "BitwardenWatchApp/Assets.xcassets/ComplicationIcon.imageset/passy-logo.pdf",
          "BitwardenWatchWidgetExtension/Assets.xcassets/AccentedComplicationIcon.imageset/passy-logo.pdf"] {
    write(pdf(palette: light), f)
}
print("logo assets written")
