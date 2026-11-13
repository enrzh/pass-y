// Regenerates BitwardenResources/Icons.xcassets PDFs from SF Symbols (template images).
// usage: swift Scripts-passy/generate_sf_icons.swift BitwardenResources/Icons.xcassets
import AppKit

let map: [String: String] = [
    "archive24": "archivebox", "arrow-right16": "arrow.right", "arrow-sync24": "arrow.triangle.2.circlepath",
    "arrow-up": "arrow.up", "bank-account24": "building.columns", "business16": "building.2",
    "camera16": "camera", "camera24": "camera", "card24": "creditcard", "check-circle24": "checkmark.circle",
    "check-square16": "checkmark.square", "check12": "checkmark", "check16": "checkmark", "check24": "checkmark",
    "chevron-down16": "chevron.down", "chevron-down24": "chevron.down", "chevron-right16": "chevron.right",
    "circle-x16": "xmark.circle", "circle-x24": "xmark.circle", "clock16": "clock", "clock24": "clock",
    "close16": "xmark", "cog16": "gearshape", "cog24": "gearshape", "copy16": "doc.on.doc", "copy24": "doc.on.doc",
    "desktop24": "desktopcomputer", "do-not16": "nosign", "download24": "square.and.arrow.down",
    "ellipsis-horizontal24": "ellipsis", "ellipsis-vertical24": "ellipsis", "external-link16": "arrow.up.right.square",
    "external-link24": "arrow.up.right.square", "eye-slash24": "eye.slash", "eye24": "eye", "file-text24": "doc.text",
    "file-upload24": "square.and.arrow.up", "file24": "doc", "folder16": "folder", "folder24": "folder",
    "generate16": "arrow.clockwise", "generate24": "arrow.clockwise", "globe24": "globe", "horizontal-dots16": "ellipsis",
    "id-card24": "person.text.rectangle", "information-circle24": "info.circle", "key16": "key", "key24": "key",
    "lightbulb24": "lightbulb", "link16": "link", "locked24": "lock", "minus-circle24": "minus.circle", "minus16": "minus",
    "mobile16": "iphone", "other": "ellipsis.circle", "paint-brush": "paintbrush", "paperclip16": "paperclip",
    "passkey24": "person.badge.key", "pencil24": "pencil", "pencil32": "pencil", "plus16": "plus", "plus24": "plus",
    "plus32": "plus", "provider16": "building", "puzzle24": "puzzlepiece", "question-circle12": "questionmark.circle",
    "question-circle16": "questionmark.circle", "question-circle24": "questionmark.circle",
    "restart-filled24": "arrow.counterclockwise", "search16": "magnifyingglass", "search24": "magnifyingglass",
    "share16": "square.and.arrow.up", "sharedFolder16": "folder.badge.person.crop",
    "sharedFolder24": "folder.badge.person.crop", "shield24": "shield", "square16": "square",
    "star-filled24": "star.fill", "star24": "star", "sticky-note16": "note.text", "sticky-note24": "note.text",
    "trash16": "trash", "trash24": "trash", "unlocked24": "lock.open", "vault-settings": "lock.shield",
    "warning16": "exclamationmark.triangle", "warning24": "exclamationmark.triangle",
]

let root = CommandLine.arguments[1]
var done = 0
for (name, symbol) in map {
    let dir = "\(root)/\(name).imageset"
    guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir),
          let pdf = files.first(where: { $0.hasSuffix(".pdf") }) else { print("skip \(name)"); continue }
    let digits = name.filter(\.isNumber)
    let size = CGFloat(Int(digits.suffix(2)) ?? 24)
    let canvas = (size == 12 || size == 16 || size == 24 || size == 32) ? size : 24
    var box = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    let cfg = NSImage.SymbolConfiguration(pointSize: canvas * 0.72, weight: .regular)
    guard let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else {
        print("no symbol \(symbol)"); continue
    }
    // Rasterize the symbol at 12x into a transparent bitmap (vector symbols fill solid in PDF contexts),
    // then embed it in a PDF page so the asset keeps its single-file template format.
    let px = Int(canvas * 12)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let bctx = NSGraphicsContext(bitmapImageRep: rep) else { continue }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = bctx
    let s = img.size
    let scale = min(canvas / s.width, canvas / s.height, 1.0) * 12
    let w = s.width * scale, h = s.height * scale
    img.draw(in: CGRect(x: (CGFloat(px) - w) / 2, y: (CGFloat(px) - h) / 2, width: w, height: h),
             from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    guard let cg = rep.cgImage,
          let ctx = CGContext(URL(fileURLWithPath: "\(dir)/\(pdf)") as CFURL, mediaBox: &box, nil) else { continue }
    ctx.beginPDFPage(nil)
    ctx.draw(cg, in: box)
    ctx.endPDFPage(); ctx.closePDF()
    done += 1
}
print("wrote \(done) icons")
