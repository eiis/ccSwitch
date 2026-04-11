import SwiftUI

struct MenuBarRootView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.accounts.isEmpty {
                Text("No imported accounts")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(appState.accounts) { account in
                    Button {
                        appState.switchAccount(account)
                    } label: {
                        AccountRowView(account: account, isCurrent: appState.currentAccountID == account.id)
                    }
                    .buttonStyle(.plain)
                    .disabled(appState.isBusy)
                }
            }

            Divider()

            VStack(spacing: 8) {
                MenuActionButton(title: "Add OpenAI Account", systemImage: "person.crop.circle.badge.plus") {
                    appState.startOAuthLogin()
                }
                .disabled(appState.isBusy)

                MenuActionButton(title: "Import Current Codex Auth", systemImage: "square.and.arrow.down") {
                    appState.importCurrentAuth()
                }
                .disabled(appState.isBusy)

                MenuActionButton(title: "Manage Accounts", systemImage: "rectangle.grid.1x2") {
                    openWindow(id: "accounts")
                }

                MenuActionButton(title: "Refresh", systemImage: "arrow.clockwise") {
                    appState.refreshStatus()
                    appState.refreshAllUsage()
                }
                .disabled(appState.isBusy)

            }

            if let banner = appState.banner {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(banner.title)
                            .font(.system(size: 11, weight: .bold))
                        if let detail = banner.detail {
                            Text(detail)
                                .font(.system(size: 11))
                        }
                    }
                    .foregroundStyle(bannerToneColor(banner.tone))
                    .font(.system(size: 11))
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    if appState.isBusy {
                        Button("Cancel") {
                            appState.cancelOAuthLogin()
                        }
                        .font(.system(size: 11, weight: .medium))
                    }
                }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 340)
        .onAppear {
            appState.refreshStatus()
        }
    }

    private func bannerToneColor(_ tone: BannerMessage.Tone) -> Color {
        switch tone {
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .info: return .blue
        }
    }
}

private struct MenuActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
