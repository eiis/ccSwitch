#!/usr/bin/env swift

import AppKit
import Foundation

// Initialize AppKit graphics subsystem (required for headless rendering)
let _ = NSApplication.shared

// MARK: - Icon Drawing (mirrors AppIconRenderer.makeIcon)

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let context = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
    let cornerRadius = size * 0.24

    let backgroundPath = CGPath(
        roundedRect: rect.insetBy(dx: size * 0.03, dy: size * 0.03),
        cornerWidth: cornerRadius,
        cornerHeight: cornerRadius,
        transform: nil
    )

    context.saveGState()
    context.addPath(backgroundPath)
    context.clip()

    let colors = [
        NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.95, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.03, green: 0.76, blue: 0.74, alpha: 1).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: size * 0.12, y: size),
        end: CGPoint(x: size * 0.88, y: 0),
        options: []
    )

    let glowColors = [
        NSColor.white.withAlphaComponent(0.34).cgColor,
        NSColor.white.withAlphaComponent(0.02).cgColor
    ] as CFArray
    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: glowColors, locations: [0, 1])!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: size * 0.34, y: size * 0.76),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.34, y: size * 0.76),
        endRadius: size * 0.62,
        options: []
    )
    context.restoreGState()

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.26).cgColor)
    context.setLineWidth(size * 0.016)
    context.addPath(backgroundPath)
    context.strokePath()

    let arrowLineWidth = size * 0.16
    let insetX = size * 0.16
    let centerY = size * 0.5

    let leftArrow = CGMutablePath()
    leftArrow.move(to: CGPoint(x: size * 0.66, y: size * 0.24))
    leftArrow.addLine(to: CGPoint(x: insetX, y: centerY))
    leftArrow.addLine(to: CGPoint(x: size * 0.66, y: size * 0.76))

    context.setLineWidth(arrowLineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.setStrokeColor(NSColor.white.cgColor)
    context.addPath(leftArrow)
    context.strokePath()

    let rightArrow = CGMutablePath()
    rightArrow.move(to: CGPoint(x: size * 0.34, y: size * 0.24))
    rightArrow.addLine(to: CGPoint(x: size - insetX, y: centerY))
    rightArrow.addLine(to: CGPoint(x: size * 0.34, y: size * 0.76))

    context.setStrokeColor(NSColor.white.withAlphaComponent(0.96).cgColor)
    context.addPath(rightArrow)
    context.strokePath()

    let dotDiameter = size * 0.11
    let dotRect = CGRect(
        x: (size - dotDiameter) / 2,
        y: (size - dotDiameter) / 2,
        width: dotDiameter,
        height: dotDiameter
    )
    context.setFillColor(NSColor(calibratedWhite: 1, alpha: 0.98).cgColor)
    context.fillEllipse(in: dotRect)

    image.unlockFocus()
    return image
}

// MARK: - PNG Export with correct DPI

func writePNG(image: NSImage, pixelSize: Int, pointSize: Int, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
    }
    // Set point size so DPI is correct (72 for @1x, 144 for @2x)
    rep.size = NSSize(width: pointSize, height: pointSize)

    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }
    try pngData.write(to: url)
}

// MARK: - Main

guard CommandLine.arguments.count > 1 else {
    fputs("Usage: generate_icon.swift <output_directory>\n", stderr)
    exit(1)
}

let outputDir = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetDir = outputDir.appendingPathComponent("AppIcon.iconset")

try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

// (filename, pixel size, point size)
let variants: [(String, Int, Int)] = [
    ("icon_16x16.png",      16,   16),
    ("icon_16x16@2x.png",   32,   16),
    ("icon_32x32.png",      32,   32),
    ("icon_32x32@2x.png",   64,   32),
    ("icon_128x128.png",    128,  128),
    ("icon_128x128@2x.png", 256,  128),
    ("icon_256x256.png",    256,  256),
    ("icon_256x256@2x.png", 512,  256),
    ("icon_512x512.png",    512,  512),
    ("icon_512x512@2x.png", 1024, 512),
]

for (filename, pixelSize, pointSize) in variants {
    let image = makeIcon(size: CGFloat(pixelSize))
    let fileURL = iconsetDir.appendingPathComponent(filename)
    try writePNG(image: image, pixelSize: pixelSize, pointSize: pointSize, to: fileURL)
}

print("Generated iconset at: \(iconsetDir.path)")
