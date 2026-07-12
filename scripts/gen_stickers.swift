#!/usr/bin/env swift
// Generate the iMessage sticker pack assets in LezgiStickers/Stickers.xcstickers.
//
// Downscales the illustrated eagle stickers from <repo>/LezgiStickers/ to the
// 618x618 sticker canvas (large grid size), renders the iMessage app icon set,
// and writes every Contents.json the asset catalog needs.
// Regenerate with `swift scripts/gen_stickers.swift` rather than editing by hand.

import AppKit
import UniformTypeIdentifiers

// MARK: - Sticker definitions

// Illustrated eagle stickers generated externally (ChatGPT), stored as
// 1024x1024 transparent PNGs in <repo>/LezgiStickers/.
struct ImageSticker {
    let source: String  // png base name in the source folder
    let phrase: String  // Lezgi phrase the emotion stands for
}

let imageStickers: [ImageSticker] = [
    ImageSticker(source: "salam",      phrase: "Салам!"),
    ImageSticker(source: "thanks",     phrase: "Сагърай!"),
    ImageSticker(source: "sweetheart", phrase: "Чан!"),
    ImageSticker(source: "great",      phrase: "Хъсан я!"),
    ImageSticker(source: "yes",        phrase: "Эхь"),
    ImageSticker(source: "no",         phrase: "Ваъ"),
    ImageSticker(source: "howareyou",  phrase: "Вун гьикӀ я?"),
    ImageSticker(source: "loveyou",    phrase: "Заз вун кӀанда"),
    ImageSticker(source: "sorry",      phrase: "Багъишламиша"),
    ImageSticker(source: "bravo",      phrase: "Баркалла!"),
    ImageSticker(source: "congrats",   phrase: "Мубарак хьуй!"),
    ImageSticker(source: "welcome",    phrase: "Хушгелди!"),
    ImageSticker(source: "comehere",   phrase: "Ша!"),
    ImageSticker(source: "morning",    phrase: "Пакаман хийирар!"),
    ImageSticker(source: "angry",      phrase: "Бес я!"),
    ImageSticker(source: "goodnight",  phrase: "Хъсан ахварар!"),
    ImageSticker(source: "prayer",     phrase: "Амин!"),
    ImageSticker(source: "lezginka",   phrase: "Кьуьл ая!"),
    ImageSticker(source: "khinkal",    phrase: "Нуш хьуй!"),
]

// MARK: - Paths

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // scripts
    .deletingLastPathComponent()   // repo root
let catalog = repoRoot
    .appendingPathComponent("LezgiKeyboard/LezgiStickers/Stickers.xcstickers")
let imageSourceDir = repoRoot.appendingPathComponent("LezgiStickers")
let packDir = catalog.appendingPathComponent("Sticker Pack.stickerpack")
let iconDir = catalog.appendingPathComponent("iMessage App Icon.stickersiconset")

let fm = FileManager.default

// MARK: - Drawing helpers

func color(_ hex: String) -> CGColor {
    let v = UInt32(hex, radix: 16)!
    return CGColor(red: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255,
                   alpha: 1)
}

func makeContext(width: Int, height: Int, opaque: Bool) -> CGContext {
    let alpha: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
    return CGContext(data: nil, width: width, height: height,
                     bitsPerComponent: 8, bytesPerRow: 0,
                     space: CGColorSpace(name: CGColorSpace.sRGB)!,
                     bitmapInfo: alpha.rawValue)!
}

func savePNG(_ ctx: CGContext, to url: URL) {
    let image = ctx.makeImage()!
    let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - Image sticker rendering

func loadImage(_ url: URL) -> CGImage {
    guard let image = NSImage(contentsOf: url),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        fatalError("cannot load \(url.path)")
    }
    return cg
}

// actool warns on stickers over 500 KB ("cannot be larger than 512000 bytes"),
// so oversized originals would be rejected by App Store validation.
let enforceStickerSizeLimit = true

/// Place a source illustration into the pack. Originals are copied byte-for-byte;
/// with the size limit enforced, oversized drawings are re-rendered at the
/// largest side length that still fits (found by binary search).
func renderImageSticker(from source: URL, to url: URL) {
    guard enforceStickerSizeLimit else {
        try! fm.copyItem(at: source, to: url)
        return
    }

    let image = loadImage(source)

    func render(side: Int) -> Int {
        let ctx = makeContext(width: side, height: side, opaque: false)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        savePNG(ctx, to: url)
        return try! fm.attributesOfItem(atPath: url.path)[.size] as! Int
    }

    if render(side: image.width) <= 500_000 { return }
    var lo = 300, hi = image.width  // lo always fits, hi never does
    while hi - lo > 8 {
        let mid = (lo + hi) / 2
        if render(side: mid) <= 500_000 { lo = mid } else { hi = mid }
    }
    _ = render(side: lo)
    print("  (\(source.lastPathComponent) resized to \(lo)px to fit 500 KB)")
}

// MARK: - Icon rendering

func renderIcon(width: Int, height: Int, to url: URL) {
    let ctx = makeContext(width: width, height: height, opaque: true)
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color("007AFF"), color("5856D6")] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: CGFloat(height)),
                           end: CGPoint(x: CGFloat(width), y: 0),
                           options: [])

    // the waving eagle mascot, centered, at ~86% of the short side
    let eagle = loadImage(imageSourceDir.appendingPathComponent("salam.png"))
    let side = CGFloat(min(width, height)) * 0.86
    ctx.interpolationQuality = .high
    ctx.draw(eagle, in: CGRect(x: (CGFloat(width) - side) / 2,
                               y: (CGFloat(height) - side) / 2,
                               width: side, height: side))

    savePNG(ctx, to: url)
}

// (idiom, platform, size in pt, scale, pixel w, pixel h)
let iconSlots: [(idiom: String, platform: String?, size: String, scale: String, w: Int, h: Int)] = [
    ("universal",     "ios", "27x20",     "2x", 54, 40),
    ("universal",     "ios", "27x20",     "3x", 81, 60),
    ("universal",     "ios", "32x24",     "2x", 64, 48),
    ("universal",     "ios", "32x24",     "3x", 96, 72),
    ("iphone",        nil,   "60x45",     "2x", 120, 90),
    ("iphone",        nil,   "60x45",     "3x", 180, 135),
    ("ipad",          nil,   "67x50",     "2x", 134, 100),
    ("ipad",          nil,   "74x55",     "2x", 148, 110),
    ("ios-marketing", nil,   "1024x1024", "1x", 1024, 1024),
    ("ios-marketing", "ios", "1024x768",  "1x", 1024, 768),
]

// MARK: - Contents.json helpers

let xcodeInfo: [String: Any] = ["author": "xcode", "version": 1]

func writeJSON(_ object: [String: Any], to url: URL) {
    let data = try! JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    try! data.write(to: url)
}

// MARK: - Generate

try? fm.removeItem(at: catalog)
try! fm.createDirectory(at: packDir, withIntermediateDirectories: true)
try! fm.createDirectory(at: iconDir, withIntermediateDirectories: true)

writeJSON(["info": xcodeInfo], to: catalog.appendingPathComponent("Contents.json"))

for imageSticker in imageStickers {
    let name = "eagle_\(imageSticker.source)"
    let stickerDir = packDir.appendingPathComponent("\(name).sticker")
    try! fm.createDirectory(at: stickerDir, withIntermediateDirectories: true)
    renderImageSticker(from: imageSourceDir.appendingPathComponent("\(imageSticker.source).png"),
                       to: stickerDir.appendingPathComponent("\(name).png"))
    writeJSON([
        "info": xcodeInfo,
        "properties": ["filename": "\(name).png"],
    ], to: stickerDir.appendingPathComponent("Contents.json"))
    print("sticker \(name).png  (\(imageSticker.phrase))")
}

writeJSON([
    "info": xcodeInfo,
    "properties": ["grid-size": "large"],
    "stickers": imageStickers.map { ["filename": "eagle_\($0.source).sticker"] },
], to: packDir.appendingPathComponent("Contents.json"))

var iconImages: [[String: Any]] = []
for slot in iconSlots {
    let name = "icon-\(slot.w)x\(slot.h).png"
    renderIcon(width: slot.w, height: slot.h, to: iconDir.appendingPathComponent(name))
    var entry: [String: Any] = [
        "filename": name, "idiom": slot.idiom, "scale": slot.scale, "size": slot.size,
    ]
    if let platform = slot.platform { entry["platform"] = platform }
    iconImages.append(entry)
    print("icon \(name)")
}
writeJSON(["images": iconImages, "info": xcodeInfo],
          to: iconDir.appendingPathComponent("Contents.json"))

print("done: \(imageStickers.count) stickers, \(iconSlots.count) icons")
