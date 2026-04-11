import SwiftUI

struct AccountRowView: View {
    let account: Account
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 8) {
                UsageRingView(
                    percent: account.usage?.fiveHour?.usedPercent,
                    accent: isCurrent ? .blue : .teal,
                    title: "5h",
                    subtitle: account.usage?.fiveHour == nil ? "N/A" : "Short",
                    size: 42,
                    lineWidth: 6
                )

                UsageRingView(
                    percent: account.usage?.oneWeek?.usedPercent,
                    accent: .orange,
                    title: "7d",
                    subtitle: account.usage?.oneWeek == nil ? "N/A" : "Week",
                    size: 42,
                    lineWidth: 6
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(account.email ?? account.label)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if isCurrent {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }

                if let planType = account.planType, !planType.isEmpty {
                    PlanBadge(planType: planType)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isCurrent ? Color.blue.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isCurrent ? Color.blue.opacity(0.22) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
