import SwiftUI

struct UsageRingView: View {
    let percent: Double?
    let accent: Color
    let title: String
    let subtitle: String
    var size: CGFloat = 52
    var lineWidth: CGFloat = 8

    private var clampedPercent: Double {
        min(max(percent ?? 0, 0), 100)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(accent.opacity(0.14), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: clampedPercent / 100)
                    .stroke(
                        AngularGradient(
                            colors: [accent.opacity(0.55), accent],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text(percent.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" } ?? "N/A")
                        .font(.system(size: size * 0.25, weight: .bold))
                    Text(title)
                        .font(.system(size: max(8, size * 0.17), weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size, height: size)

            Text(subtitle)
                .font(.system(size: max(9, size * 0.18), weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: size + 8)
        }
    }
}
