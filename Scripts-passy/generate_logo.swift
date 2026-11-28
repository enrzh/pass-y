#!/usr/bin/swift
// Pass-Y logo generator. One geometry (1024 grid), rendered as SVG + PNG + PDF; writes all app icon assets.
// R8 mark: a solid shield with a Y (the Y of Pass-Y) knocked out in the centre. Flat, black and white only.
// Usage: swift Scripts-passy/generate_logo.swift <repo-root>
import AppKit
import CoreGraphics

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default

struct Palette { let bg: (CGFloat, CGFloat, CGFloat)?; let fg: (CGFloat, CGFloat, CGFloat); let hole: (CGFloat, CGFloat, CGFloat) }
let light = Palette(bg: (1, 1, 1), fg: (0, 0, 0), hole: (1, 1, 1))       // white tile, black mark
let dark = Palette(bg: (0, 0, 0), fg: (1, 1, 1), hole: (0, 0, 0))          // inverted
let tinted = Palette(bg: (0, 0, 0), fg: (1, 1, 1), hole: (0, 0, 0))        // grayscale mask for tinting
let markOnly = Palette(bg: nil, fg: (0, 0, 0), hole: (0, 0, 0))

func col(_ c: (CGFloat, CGFloat, CGFloat)) -> CGColor { CGColor(red: c.0, green: c.1, blue: c.2, alpha: 1) }

// Mark geometry (1024 grid): shield silhouette with a Y centred inside. Solid shield, Y knocked out (flat, two tones).

func shieldPath(scale s: CGFloat = 1) -> CGPath {
    // Top edge rises gently to a centre peak, straight sides, curved flanks into a bottom point.
    let p = CGMutablePath()
    func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: 512 + (x - 512) * s, y: 520 + (y - 520) * s) }
    p.move(to: pt(512, 168))
    p.addCurve(to: pt(792, 262), control1: pt(590, 222), control2: pt(700, 262))
    p.addLine(to: pt(792, 506))
    p.addCurve(to: pt(512, 872), control1: pt(792, 700), control2: pt(660, 810))
    p.addCurve(to: pt(232, 506), control1: pt(364, 810), control2: pt(232, 700))
    p.addLine(to: pt(232, 262))
    p.addCurve(to: pt(512, 168), control1: pt(324, 262), control2: pt(434, 222))
    p.closeSubpath()
    return p
}

func yPath(top: CGFloat, fork: CGFloat, bottom: CGFloat, half: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 512 - half, y: top)); p.addLine(to: CGPoint(x: 512, y: fork))
    p.addLine(to: CGPoint(x: 512 + half, y: top))
    p.move(to: CGPoint(x: 512, y: fork)); p.addLine(to: CGPoint(x: 512, y: bottom))
    return p
}

/// Draws the mark on a 1024 grid scaled into `size` (y axis flipped to match SVG).
/// With a background the Y is painted in the background colour; without one it is punched out (template images).
func drawMark(_ ctx: CGContext, size: CGFloat, palette: Palette, punchHole: Bool = false) {
    let k = size / 1024
    ctx.saveGState()
    ctx.translateBy(x: 0, y: size); ctx.scaleBy(x: k, y: -k)
    if let bg = palette.bg { ctx.setFillColor(col(bg)); ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024)) }
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    let yColor = palette.bg ?? palette.hole
    let clearY = palette.bg == nil
    func strokeY(_ path: CGPath, width: CGFloat) {
        if clearY { ctx.setBlendMode(.clear) } else { ctx.setStrokeColor(col(yColor)) }
        ctx.setLineWidth(width); ctx.addPath(path); ctx.strokePath(); ctx.setBlendMode(.normal)
    }
    // Solid shield; a round-join stroke on an inset path softens the corners and the bottom point.
    ctx.setFillColor(col(palette.fg)); ctx.setStrokeColor(col(palette.fg)); ctx.setLineWidth(48)
    ctx.addPath(shieldPath(scale: 0.93)); ctx.drawPath(using: .fillStroke)
    strokeY(yPath(top: 366, fork: 526, bottom: 712, half: 120), width: 90)
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
/// SVG path data of the (inset) shield, taken from the same CGPath as the raster output.
var svgShield: String {
    var d = ""
    func f(_ v: CGFloat) -> String { String(format: "%.1f", v) }
    shieldPath(scale: 0.93).applyWithBlock { e in
        let q = e.pointee.points
        switch e.pointee.type {
        case .moveToPoint: d += "M\(f(q[0].x)) \(f(q[0].y)) "
        case .addLineToPoint: d += "L\(f(q[0].x)) \(f(q[0].y)) "
        case .addCurveToPoint: d += "C\(f(q[0].x)) \(f(q[0].y)) \(f(q[1].x)) \(f(q[1].y)) \(f(q[2].x)) \(f(q[2].y)) "
        case .closeSubpath: d += "Z"
        default: break
        }
    }
    return d
}
func svg(_ p: Palette) -> String {
    let bgRect = p.bg.map { "<rect width=\"1024\" height=\"1024\" fill=\"\(hex($0))\"/>" } ?? ""
    let fg = hex(p.fg), yc = hex(p.bg ?? p.hole)
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
      \(bgRect)
      <path d="\(svgShield)" fill="\(fg)" stroke="\(fg)" stroke-width="48" stroke-linejoin="round"/>
      <path d="M392 366 L512 526 L632 366 M512 526 L512 712" fill="none" stroke="\(yc)" stroke-width="90" stroke-linecap="round" stroke-linejoin="round"/>
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
// The mark on the watch app's (black) setup page: the dark variant, so only the shield shows.
for n in 1 ... 3 {
    write(pdf(palette: dark), "BitwardenWatchApp/Assets.xcassets/BitwardenImagetype.imageset/passy-logo-\(n).pdf")
}
for f in ["BitwardenWatchApp/Assets.xcassets/ComplicationIcon.imageset/passy-logo.pdf",
          "BitwardenWatchWidgetExtension/Assets.xcassets/AccentedComplicationIcon.imageset/passy-logo.pdf"] {
    write(pdf(palette: light), f)
}
// --- in-app wordmark (template image): key mark + "Pass-Y" text, 282x44 pt @1x/2x/3x ---
let blackMark = Palette(bg: nil, fg: (0, 0, 0), hole: (0, 0, 0))
func wordmark(scale: CGFloat) -> Data {
    let w = Int(282 * scale), h = Int(44 * scale)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let markSize = CGFloat(h)
    let font = NSFont.systemFont(ofSize: 32 * scale, weight: .bold)
    let str = NSAttributedString(string: "Pass-Y", attributes: [.font: font, .foregroundColor: NSColor.black])
    let textSize = str.size()
    let gap = 10 * scale
    let total = markSize + gap + textSize.width
    let x0 = (CGFloat(w) - total) / 2
    ctx.saveGState(); ctx.translateBy(x: x0, y: 0)
    drawMark(ctx, size: markSize, palette: blackMark, punchHole: true)
    ctx.restoreGState()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    str.draw(at: NSPoint(x: x0 + markSize + gap, y: (CGFloat(h) - textSize.height) / 2))
    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}
for dir in ["Bitwarden/Application/Support/Assets.xcassets/logoBitwarden.imageset",
            "BitwardenShared/UI/Platform/Application/Support/Images.xcassets/logo.imageset"] {
    write(wordmark(scale: 1), "\(dir)/logo.png"); write(wordmark(scale: 2), "\(dir)/logo@2x.png"); write(wordmark(scale: 3), "\(dir)/logo@3x.png")
}
// --- watch Dev/Beta sets reference their own file names; keep them identical to the main icon ---
for set in ["AppIcon-Dev", "AppIcon-Beta"] {
    write(png(size: 1024, palette: light), "BitwardenWatchApp/Assets.xcassets/\(set).appiconset/\(set).png")
}
print("logo assets written")
