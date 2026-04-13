import SwiftUI
import UniformTypeIdentifiers

struct AccountManagerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var isImporterPresented = false
    @State private var isOAuthGuidePresented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                actionBar
                accountList
                footer
            }
            .padding(22)
        }
        .background(
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 760, minHeight: 560)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                appState.importAuthFile(from: url)
            case .failure(let error):
                appState.lastError = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Accounts")
                    .font(.system(size: 26, weight: .bold))
                Text("\(appState.accounts.count) saved • \(appState.currentAccount?.email ?? "No active account")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(appState.authFileName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.14), Color.teal.opacity(0.08), Color.white.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            ActionButton(title: "Add Account", systemImage: "person.crop.circle.badge.plus", tint: .pink) {
                isOAuthGuidePresented = true
            }
            .disabled(appState.isBusy)

            ActionButton(title: "Import Current", systemImage: "square.and.arrow.down.fill", tint: .blue) {
                appState.importCurrentAuth()
            }

            ActionButton(title: "Import JSON", systemImage: "doc.badge.plus", tint: .teal) {
                isImporterPresented = true
            }

            ActionButton(title: "Refresh", systemImage: "arrow.clockwise", tint: .orange) {
                appState.refreshStatus()
                appState.refreshAllUsage()
            }

            Spacer()

            if let current = appState.currentAccount {
                Text(current.email ?? current.label)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.08))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                    .lineLimit(1)
            }
        }
        .sheet(isPresented: $isOAuthGuidePresented) {
            OAuthGuideSheet {
                isOAuthGuidePresented = false
                appState.startOAuthLogin()
            }
        }
    }

    private var accountList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.system(size: 16, weight: .bold))

            if appState.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                    Text("No Accounts Yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Import your current Codex auth or load an auth JSON file to start switching accounts.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(appState.accounts) { account in
                        EditableAccountRow(
                            account: account,
                            isCurrent: appState.currentAccountID == account.id,
                            onSwitch: { appState.switchAccount(account) },
                            onDelete: { appState.deleteAccount(account) }
                        )
                    }
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let banner = appState.banner {
                BannerCard(message: banner)
            }
        }
    }
}

private struct EditableAccountRow: View {
    let account: Account
    let isCurrent: Bool
    let onSwitch: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isCurrent ? Color.blue.opacity(0.9) : Color.white.opacity(0.45), lineWidth: 2)
                    .frame(width: 30, height: 30)

                Text(account.email ?? "Unknown email")
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)

                Spacer()

                if let planType = account.planType, !planType.isEmpty {
                    PlanBadge(planType: planType)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let accountId = primaryIdentity {
                    metaLine("User ID", value: accountId)
                }

                if let authMode = authModeText {
                    metaLine("Sign-in", value: authMode)
                }
            }

            UsageBarRow(
                title: "5h",
                icon: "clock",
                percent: account.usage?.fiveHour?.usedPercent,
                accent: isCurrent ? .blue : .teal,
                detail: countdownText(until: account.usage?.fiveHour?.resetAt, includeDate: false)
            )

            UsageBarRow(
                title: "Weekly",
                icon: "calendar",
                percent: account.usage?.oneWeek?.usedPercent,
                accent: .orange,
                detail: countdownText(until: account.usage?.oneWeek?.resetAt, includeDate: true)
            )

            Divider()

            HStack(spacing: 10) {
                Text(account.updatedAt.formatted(date: .numeric, time: .shortened))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Spacer()

                Button(isCurrent ? "Current" : "Set Active") {
                    onSwitch()
                }
                .buttonStyle(.borderedProminent)
                .tint(isCurrent ? .gray : .teal)
                .disabled(isCurrent)

                Button("Delete", role: .destructive) {
                    onDelete()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.11, blue: 0.22).opacity(isCurrent ? 0.98 : 0.94),
                    Color(red: 0.05, green: 0.09, blue: 0.18).opacity(isCurrent ? 0.96 : 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isCurrent ? Color.blue.opacity(0.24) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private var primaryIdentity: String? {
        account.principalId ?? account.chatGPTAccountId ?? normalized(account.accountId)
    }

    private var authModeText: String? {
        if account.auth["refresh_token"]?.stringValue?.isEmpty == false {
            return "OpenAI OAuth"
        }
        if account.auth["id_token"]?.stringValue?.isEmpty == false {
            return "Local auth.json"
        }
        return nil
    }

    @ViewBuilder
    private func metaLine(_ title: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text("\(title):")
            Text(value)
                .lineLimit(1)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
    }

    private func countdownText(until date: Date?, includeDate: Bool) -> String {
        guard let date else { return "N/A" }
        let remaining = max(Int(date.timeIntervalSinceNow), 0)
        let days = remaining / 86_400
        let hours = (remaining % 86_400) / 3_600
        let minutes = (remaining % 3_600) / 60

        let countdown: String
        if days > 0 {
            countdown = "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            countdown = "\(hours)h \(minutes)m"
        } else {
            countdown = "\(minutes)m"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = includeDate ? "MM/dd HH:mm" : "HH:mm"
        return "\(countdown)  (\(formatter.string(from: date)))"
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct UsageBarRow: View {
    let title: String
    let icon: String
    let percent: Double?
    let accent: Color
    let detail: String

    private var clampedPercent: Double {
        min(max(percent ?? 0, 0), 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(percent.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" } ?? "N/A")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(accent.opacity(0.16))
                        .frame(height: 12)

                    Capsule()
                        .fill(accent)
                        .frame(width: max(14, proxy.size.width * CGFloat(clampedPercent / 100)), height: 12)
                }
            }
            .frame(height: 12)

            HStack {
                Spacer()

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct BannerCard: View {
    let message: BannerMessage

    private var tint: Color {
        switch message.tone {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }

    private var icon: String {
        switch message.tone {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 16, weight: .bold))

            VStack(alignment: .leading, spacing: 4) {
                Text(message.title)
                    .font(.system(size: 13, weight: .bold))
                if let detail = message.detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OAuthGuideSheet: View {
    let onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Add OpenAI Account")
                .font(.system(size: 24, weight: .bold))

            Text("Before continuing, make sure the browser session matches the account you want to import.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            GuideRow(
                title: "Current browser session is reused",
                detail: "If you are already signed in to OpenAI in your browser, authorization will likely return that same account."
            )

            GuideRow(
                title: "To add a different account",
                detail: "Use an incognito/private window or sign out of the current OpenAI session before continuing."
            )

            GuideRow(
                title: "What happens after authorization",
                detail: "The app will either add a new account or refresh credentials for an existing one, and it will tell you which happened."
            )

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Continue in Browser") {
                    dismiss()
                    onContinue()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
        }
        .padding(24)
        .frame(width: 520)
    }
}

private struct GuideRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
