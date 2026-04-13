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
            MenuBarIconView(appState: appState)
                .onAppear {
                    appState.bootstrap()
                }
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
