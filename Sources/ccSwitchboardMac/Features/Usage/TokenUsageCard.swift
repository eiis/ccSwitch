import SwiftUI

struct TokenUsageCard: View {
    @EnvironmentObject private var appState: AppState
    @State private var showsPerAccount = false

    private var summary: TokenUsageSummary { appState.tokenUsageStore.summary }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 12) {
                bucketTile("Today", bucket: summary.today, accent: .blue)
                bucketTile("7 Days", bucket: summary.sevenDays, accent: .teal)
                bucketTile("This Month", bucket: summary.month, accent: .purple)
            }

            if !summary.perAccountMonth.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showsPerAccount.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showsPerAccount ? "chevron.down" : "chevron.right")
                        Text("Per-account (this month)")
                        Spacer()
                        Text("based on switch log")
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)

                if showsPerAccount {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(perAccountRows, id: \.id) { row in
                            HStack {
                                Text(row.label)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(formatTokens(row.bucket.totalTokens))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(formatCost(row.bucket))
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(minWidth: 62, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.10), Color.blue.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Token Usage")
                    .font(.system(size: 15, weight: .bold))
                Text("Local only · read from ~/.codex/sessions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                appState.tokenUsageStore.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .bold))
                    .padding(6)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(appState.tokenUsageStore.isRefreshing)
        }
    }

    private func bucketTile(_ title: String, bucket: TokenUsageBucket, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            Text(formatCost(bucket))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
            Text("\(formatTokens(bucket.totalTokens)) tokens")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private struct PerAccountRow: Identifiable {
        let id: String
        let label: String
        let bucket: TokenUsageBucket
    }

    private var perAccountRows: [PerAccountRow] {
        summary.perAccountMonth.map { (id, bucket) in
            let label = appState.accounts.first(where: { $0.id == id })?.email
                ?? appState.accounts.first(where: { $0.id == id })?.label
                ?? "Unknown (\(id.prefix(6)))"
            return PerAccountRow(id: id, label: label, bucket: bucket)
        }
        .sorted { $0.bucket.totalTokens > $1.bucket.totalTokens }
    }

    private func formatTokens(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.2fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fk", Double(n) / 1_000)
        }
        return "\(n)"
    }

    private func formatCost(_ bucket: TokenUsageBucket) -> String {
        if bucket.totalTokens == 0 { return "$0.00" }
        let base = String(format: "$%.2f", bucket.costUSD)
        return bucket.hasUnknownModel ? base + "*" : base
    }
}
