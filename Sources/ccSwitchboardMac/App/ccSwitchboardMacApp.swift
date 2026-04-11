import SwiftUI

@main
struct ccSwitchboardMacApp: App {
    @StateObject private var appState = AppState()

    init() {
        AppIconRenderer.installAsApplicationIcon()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appState)
                .onAppear {
                    appState.bootstrap()
                }
        } label: {
            Image(systemName: "arrow.left.arrow.right.circle")
                .accessibilityLabel("ccSwitchboard")
        }
        .menuBarExtraStyle(.window)

        Window("Accounts", id: "accounts") {
            AccountManagerView()
                .environmentObject(appState)
                .onAppear {
                    appState.bootstrap()
                }
        }
        .defaultSize(width: 720, height: 520)
    }
}
