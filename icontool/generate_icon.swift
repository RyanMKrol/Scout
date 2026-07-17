#!/usr/bin/env swift
// Regenerates Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png from the design spec
// (see design/design_handoff_scout/README.md "Assets"). Run with:
//   swift icontool/generate_icon.swift
// from the repo root. CoreGraphics + ImageIO only — no design tools, no Xcode GUI.

import CoreGraphics
import Foundation
import ImageIO

let size = 1024

func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(v, lo), hi)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
    a + (b - a) * t
}

// MARK: - Background radial gradient + sweep wedge (angular gradient), per pixel

let bgCenter = (x: Double(size) * 0.30, y: Double(size) * 0.25)
let bgMaxRadius = Double(size) * 0.70
let bgCenterColor = (r: 16.0, g: 16.0, b: 21.0) // #101015
let bgEdgeColor = (r: 5.0, g: 5.0, b: 6.0) // #050506

let wedgeCenter = (x: Double(size) / 2, y: Double(size) / 2)
let wedgeColor = (r: 99.0, g: 217.0, b: 155.0) // #63D99B
let wedgeStartDeg = 250.0
let wedgePeakDeg = 358.0
let wedgeEndDeg = 360.0
let wedgePeakAlpha = 0.55

let bytesPerPixel = 4
let bytesPerRow = bytesPerPixel * size
var pixels = [UInt8](repeating: 0, count: bytesPerRow * size)

for y in 0..<size {
    let fy = Double(y) + 0.5
    for x in 0..<size {
        let fx = Double(x) + 0.5

        // Background: radial gradient, center at (30%, 25%) from top-left.
        let dxBG = fx - bgCenter.x
        let dyBG = fy - bgCenter.y
        let distBG = (dxBG * dxBG + dyBG * dyBG).squareRoot()
        let t = clamp(distBG / bgMaxRadius, 0, 1)
        var r = lerp(bgCenterColor.r, bgEdgeColor.r, t)
        var g = lerp(bgCenterColor.g, bgEdgeColor.g, t)
        var b = lerp(bgCenterColor.b, bgEdgeColor.b, t)

        // Sweep wedge: angular gradient centered mid-icon, angle measured clockwise from
        // the top (matches SweepWedgeView's AngularGradient(center: .center) convention).
        // Transparent until 250°, ramps to accent at 55% alpha by 358°, back to
        // transparent at 360° — composited OVER the opaque background above.
        let dxW = fx - wedgeCenter.x
        let dyW = fy - wedgeCenter.y
        var angle = atan2(dxW, -dyW) * 180.0 / Double.pi
        if angle < 0 { angle += 360.0 }

        var wedgeAlpha = 0.0
        if angle >= wedgeStartDeg, angle < wedgePeakDeg {
            let t2 = (angle - wedgeStartDeg) / (wedgePeakDeg - wedgeStartDeg)
            wedgeAlpha = wedgePeakAlpha * t2
        } else if angle >= wedgePeakDeg, angle <= wedgeEndDeg {
            let t2 = (angle - wedgePeakDeg) / (wedgeEndDeg - wedgePeakDeg)
            wedgeAlpha = wedgePeakAlpha * (1 - t2)
        }

        if wedgeAlpha > 0 {
            r = wedgeColor.r * wedgeAlpha + r * (1 - wedgeAlpha)
            g = wedgeColor.g * wedgeAlpha + g * (1 - wedgeAlpha)
            b = wedgeColor.b * wedgeAlpha + b * (1 - wedgeAlpha)
        }

        let offset = y * bytesPerRow + x * bytesPerPixel
        pixels[offset + 0] = UInt8(clamp(r, 0, 255).rounded())
        pixels[offset + 1] = UInt8(clamp(g, 0, 255).rounded())
        pixels[offset + 2] = UInt8(clamp(b, 0, 255).rounded())
        pixels[offset + 3] = 255
    }
}

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let provider = CGDataProvider(data: Data(pixels) as CFData) else {
    fatalError("Failed to create data provider")
}
guard let baseImage = CGImage(
    width: size,
    height: size,
    bitsPerComponent: 8,
    bitsPerPixel: 32,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
    provider: provider,
    decode: nil,
    shouldInterpolate: false,
    intent: .defaultIntent
) else {
    fatalError("Failed to create base image")
}

// MARK: - Final context: draw the base image, then the rings + center dot on top

guard let context = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("Failed to create final context")
}

context.draw(baseImage, in: CGRect(x: 0, y: 0, width: size, height: size))

// CG's default origin is bottom-left; the per-pixel pass above used a top-left screen
// convention. Flip so the vector drawing below lines up with it.
context.saveGState()
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: 1, y: -1)

let ringCenter = CGPoint(x: Double(size) / 2, y: Double(size) / 2)

func strokeRing(radius: CGFloat, lineWidth: CGFloat, white: CGFloat, alpha: CGFloat) {
    context.setStrokeColor(red: white, green: white, blue: white, alpha: alpha)
    context.setLineWidth(lineWidth)
    let rect = CGRect(
        x: ringCenter.x - radius,
        y: ringCenter.y - radius,
        width: radius * 2,
        height: radius * 2
    )
    context.strokeEllipse(in: rect)
}

// r 66 → 384 px, stroke 3 → 17.5 px, white 14% alpha
strokeRing(radius: 384, lineWidth: 17.5, white: 1.0, alpha: 0.14)
// r 42 → 244 px, same stroke, white 18% alpha
strokeRing(radius: 244, lineWidth: 17.5, white: 1.0, alpha: 0.18)

// Center dot: filled circle r 10 → 58 px, #5FE19E
let dotRadius: CGFloat = 58
context.setFillColor(red: 95.0 / 255.0, green: 225.0 / 255.0, blue: 158.0 / 255.0, alpha: 1.0)
context.fillEllipse(in: CGRect(
    x: ringCenter.x - dotRadius,
    y: ringCenter.y - dotRadius,
    width: dotRadius * 2,
    height: dotRadius * 2
))

context.restoreGState()

guard let finalImage = context.makeImage() else {
    fatalError("Failed to render final image")
}

// MARK: - Write PNG (opaque — no alpha channel, per App Store requirement)

let outputPath = "Sources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let outputURL = URL(fileURLWithPath: outputPath)

guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    "public.png" as CFString,
    1,
    nil
) else {
    fatalError("Failed to create image destination at \(outputPath)")
}

CGImageDestinationAddImage(destination, finalImage, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Failed to write PNG to \(outputPath)")
}

print("Wrote \(outputPath)")
