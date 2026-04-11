import SwiftUI

struct PlanBadge: View {
    let planType: String

    var body: some View {
        Text(displayTitle)
            .font(.system(size: 10, weight: .black))
            .tracking(0.3)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(background)
            .overlay(border)
            .clipShape(Capsule())
    }

    private var normalizedPlan: String {
        planType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var displayTitle: String {
        switch normalizedPlan {
        case "plus":
            return "PLUS"
        case "free":
            return "FREE"
        default:
            return planType.uppercased()
        }
    }

    private var foregroundColor: Color {
        switch normalizedPlan {
        case "plus":
            return Color(red: 0.47, green: 0.18, blue: 0.00)
        case "free":
            return Color(red: 0.23, green: 0.31, blue: 0.40)
        default:
            return .primary
        }
    }

    private var background: some View {
        Capsule()
            .fill(backgroundFill)
    }

    private var backgroundFill: LinearGradient {
        switch normalizedPlan {
        case "plus":
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.86, blue: 0.45),
                    Color(red: 1.00, green: 0.65, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "free":
            return LinearGradient(
                colors: [
                    Color(red: 0.89, green: 0.92, blue: 0.96),
                    Color(red: 0.80, green: 0.84, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.primary.opacity(0.07), Color.primary.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var border: some View {
        Capsule()
            .stroke(borderColor, lineWidth: 1)
    }

    private var borderColor: Color {
        switch normalizedPlan {
        case "plus":
            return Color.white.opacity(0.45)
        case "free":
            return Color.white.opacity(0.55)
        default:
            return Color.primary.opacity(0.08)
        }
    }
}
