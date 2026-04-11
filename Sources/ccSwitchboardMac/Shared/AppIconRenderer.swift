import AppKit

enum AppIconRenderer {
    @MainActor
    static func installAsApplicationIcon() {
        NSApplication.shared.applicationIconImage = makeIcon(size: 1024)
    }

    static func makeIcon(size: CGFloat) -> NSImage {
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
}
