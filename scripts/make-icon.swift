// Renders the 1024×1024 master app icon: swift scripts/make-icon.swift <output.png>
import AppKit

let canvas: CGFloat = 1024
let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func linearGradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: Int(canvas), height: Int(canvas), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// macOS icon grid: 824pt body centered on a 1024pt canvas.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: color(0x000000, 0.35))
context.addPath(bodyPath)
context.setFillColor(color(0x161B22))
context.fillPath()
context.restoreGState()

context.saveGState()
context.addPath(bodyPath)
context.clip()
context.drawLinearGradient(
    linearGradient([color(0x2D333B), color(0x0D1117)]),
    start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: []
)
context.drawRadialGradient(
    linearGradient([color(0x3FB950, 0.22), color(0x3FB950, 0)]),
    startCenter: CGPoint(x: 480, y: 560), startRadius: 0,
    endCenter: CGPoint(x: 480, y: 560), endRadius: 420, options: []
)
context.drawLinearGradient(
    linearGradient([color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)]),
    start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.maxY - 260), options: []
)
context.restoreGState()

context.saveGState()
context.addPath(bodyPath)
context.setStrokeColor(color(0xFFFFFF, 0.08))
context.setLineWidth(4)
context.strokePath()
context.restoreGState()

// Open-issue glyph: ring with a dot, filled with a green gradient.
let ringCenter = CGPoint(x: 482, y: 548)
let ringRadius: CGFloat = 232
let ringWidth: CGFloat = 66

context.saveGState()
context.addArc(center: ringCenter, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
context.setLineWidth(ringWidth)
context.replacePathWithStrokedPath()
context.addEllipse(in: CGRect(x: ringCenter.x - 74, y: ringCenter.y - 74, width: 148, height: 148))
context.clip()
context.drawLinearGradient(
    linearGradient([color(0x7EE787), color(0x2EA043)]),
    start: CGPoint(x: ringCenter.x, y: ringCenter.y + ringRadius), end: CGPoint(x: ringCenter.x, y: ringCenter.y - ringRadius),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)
context.restoreGState()

// "+" badge, separated from the ring by a cut-out in the background colour.
let badgeCenter = CGPoint(x: 718, y: 312)
let badgeRadius: CGFloat = 112

context.saveGState()
context.addEllipse(in: CGRect(x: badgeCenter.x - badgeRadius - 26, y: badgeCenter.y - badgeRadius - 26,
                              width: (badgeRadius + 26) * 2, height: (badgeRadius + 26) * 2))
context.clip()
context.drawLinearGradient(
    linearGradient([color(0x2D333B), color(0x0D1117)]),
    start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: body.minY), options: []
)
context.restoreGState()

context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0x000000, 0.4))
context.addEllipse(in: CGRect(x: badgeCenter.x - badgeRadius, y: badgeCenter.y - badgeRadius,
                              width: badgeRadius * 2, height: badgeRadius * 2))
context.setFillColor(color(0xF0F6FC))
context.fillPath()
context.restoreGState()

let arm: CGFloat = 54
let thickness: CGFloat = 30
context.setFillColor(color(0x161B22))
context.addPath(CGPath(roundedRect: CGRect(x: badgeCenter.x - arm, y: badgeCenter.y - thickness / 2, width: arm * 2, height: thickness),
                       cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
context.addPath(CGPath(roundedRect: CGRect(x: badgeCenter.x - thickness / 2, y: badgeCenter.y - arm, width: thickness, height: arm * 2),
                       cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
context.fillPath()

let image = context.makeImage()!
let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
