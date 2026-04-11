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
        VStack(alignment: .leading, spacing: 12) {
            Text("ccSwitchboard")
                .font(.system(size: 28, weight: .bold))
            Text("Switch local Codex accounts from a menu bar app, with local storage and direct auth.json control.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                StatTile(title: "Accounts", value: "\(appState.accounts.count)", accent: .blue)
                StatTile(title: "Active", value: appState.currentAccount?.email ?? "None", accent: .teal)
                StatTile(title: "Auth Path", value: appState.authFileName, accent: .orange)
            }

            Text(appState.authFilePath)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.18), Color.teal.opacity(0.12), Color.white.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            ActionButton(title: "Add OpenAI Account", systemImage: "person.crop.circle.badge.plus", tint: .pink) {
                isOAuthGuidePresented = true
            }
            .disabled(appState.isBusy)

            ActionButton(title: "Import Current Auth", systemImage: "square.and.arrow.down.fill", tint: .blue) {
                appState.importCurrentAuth()
            }

            ActionButton(title: "Import JSON File", systemImage: "doc.badge.plus", tint: .teal) {
                isImporterPresented = true
            }

            ActionButton(title: "Refresh", systemImage: "arrow.clockwise", tint: .orange) {
                appState.refreshStatus()
                appState.refreshAllUsage()
            }


            Spacer()

            if let current = appState.currentAccount {
                Label(current.email ?? current.label, systemImage: "sparkles")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color.blue.opacity(0.08))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                    .lineLimit(1)
            } else {
                Text("No active account")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
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
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 10) {
                UsageRingView(
                    percent: account.usage?.fiveHour?.usedPercent,
                    accent: isCurrent ? .blue : .teal,
                    title: "5h",
                    subtitle: account.usage?.fiveHour == nil ? "No data" : "Short window",
                    size: 58,
                    lineWidth: 8
                )

                UsageRingView(
                    percent: account.usage?.oneWeek?.usedPercent,
                    accent: .orange,
                    title: "7d",
                    subtitle: account.usage?.oneWeek == nil ? "No data" : "Weekly window",
                    size: 58,
                    lineWidth: 8
                )
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(account.email ?? "Unknown email")
                            .font(.system(size: 15, weight: .bold))
                        if isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.12))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        if let planType = account.planType, !planType.isEmpty {
                            PlanBadge(planType: planType)
                        }
                    }
                }

                HStack(spacing: 8) {
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

                    usageSummaryPills
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    isCurrent ? Color.blue.opacity(0.10) : Color.white.opacity(0.72),
                    isCurrent ? Color.teal.opacity(0.06) : Color.primary.opacity(0.03)
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

    @ViewBuilder
    private var usageSummaryPills: some View {
        if let fiveHour = account.usage?.fiveHour?.usedPercent {
            Text("5h \(fiveHour.formatted(.number.precision(.fractionLength(0))))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        }

        if let oneWeek = account.usage?.oneWeek?.usedPercent {
            Text("7d \(oneWeek.formatted(.number.precision(.fractionLength(0))))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        } else if let credits = account.usage?.credits {
            Text(credits.unlimited ? "Unlimited" : (credits.balance ?? "Credits"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.05))
                .clipShape(Capsule())
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(tint.opacity(0.12))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
