import AppKit
import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var appState: AppState

    fileprivate enum DisplayedUsage {
        case fiveHour(Double)
        case oneWeek(Double)

        var percent: Double {
            switch self {
            case .fiveHour(let value), .oneWeek(let value):
                return value
            }
        }
    }

    private var displayedUsage: DisplayedUsage? {
        if let fiveHour = appState.currentAccount?.usage?.fiveHour?.usedPercent {
            return .fiveHour(fiveHour)
        }
        if let oneWeek = appState.currentAccount?.usage?.oneWeek?.usedPercent {
            return .oneWeek(oneWeek)
        }
        return nil
    }

    private var isExhausted: Bool {
        guard let account = appState.currentAccount else { return false }
        if let p = account.usage?.fiveHour?.usedPercent, p >= 100 { return true }
        if let p = account.usage?.oneWeek?.usedPercent, p >= 100 { return true }
        return false
    }

    private var icon: NSImage {
        MenuBarStatusIconRenderer.makeIcon(
            usage: displayedUsage,
            isExhausted: isExhausted
        )
    }

    var body: some View {
        Image(nsImage: icon)
            .renderingMode(.original)
            .interpolation(.high)
            .accessibilityLabel(
                displayedUsage.map { "ccSwitchboard \(Int($0.percent.rounded()))%" } ?? "ccSwitchboard usage unavailable"
            )
    }
}

private enum MenuBarStatusIconRenderer {
    static func makeIcon(usage: MenuBarIconView.DisplayedUsage?, isExhausted: Bool, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)

        let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
        let inset: CGFloat = 1.8
        let ringRect = rect.insetBy(dx: inset, dy: inset)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = ringRect.width / 2

        let pct = min(max(usage?.percent ?? 0, 0), 100)
        let hasData = usage != nil
        let ringColor: NSColor = {
            if isExhausted {
                return NSColor.systemRed
            }
            switch usage {
            case .fiveHour:
                return NSColor.systemBlue
            case .oneWeek:
                return NSColor.systemOrange
            case nil:
                return NSColor.white.withAlphaComponent(0.92)
            }
        }()
        let trackColor = hasData
            ? ringColor.withAlphaComponent(0.14)
            : NSColor.white.withAlphaComponent(0.28)

        context.setStrokeColor(trackColor.cgColor)
        context.setLineWidth(2.4)
        context.strokeEllipse(in: ringRect)

        if pct > 0 {
            let startAngle = CGFloat.pi / 2
            let endAngle = startAngle - (CGFloat.pi * 2) * CGFloat(pct / 100)

            let arcPath = CGMutablePath()
            arcPath.addArc(
                center: center,
                radius: radius,
                startAngle: startAngle,
                endAngle: endAngle,
                clockwise: true
            )

            context.setStrokeColor(ringColor.cgColor)
            context.setLineWidth(2.8)
            context.setLineCap(.round)
            context.addPath(arcPath)
            context.strokePath()
        }

        if hasData {
            let text = "\(Int(pct.rounded()))"
            let fontSize: CGFloat = text.count >= 3 ? 6.4 : 7.2
            let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: ringColor,
                .paragraphStyle: paragraph
            ]
            let attributed = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributed.size()
            let textRect = CGRect(
                x: center.x - textSize.width / 2,
                y: center.y - textSize.height / 2 - 0.5,
                width: textSize.width,
                height: textSize.height
            )
            attributed.draw(in: textRect)
        } else {
            let dotRect = CGRect(
                x: center.x - 2.3,
                y: center.y - 2.3,
                width: 4.6,
                height: 4.6
            )
            context.setFillColor(ringColor.cgColor)
            context.fillEllipse(in: dotRect)
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
