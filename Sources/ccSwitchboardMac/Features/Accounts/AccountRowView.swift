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
                    subtitle: shortResetText(account.usage?.fiveHour?.resetAt),
                    size: 42,
                    lineWidth: 6
                )

                UsageRingView(
                    percent: account.usage?.oneWeek?.usedPercent,
                    accent: .orange,
                    title: "7d",
                    subtitle: weekResetText(account.usage?.oneWeek?.resetAt),
                    size: 42,
                    lineWidth: 6
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(account.email ?? account.label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

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

    private func shortResetText(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func weekResetText(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}
