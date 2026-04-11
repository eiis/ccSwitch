import Foundation
import SwiftUI

struct BannerMessage: Identifiable, Equatable {
    enum Tone {
        case success
        case warning
        case error
        case info
    }

    let id = UUID()
    let title: String
    let detail: String?
    let tone: Tone
}

enum ImportOutcome {
    case inserted(Account)
    case refreshed(Account)
}

@MainActor
final class AppState: ObservableObject {
    @Published var accounts: [Account] = []
    @Published var currentAccountID: String?
    @Published var lastError: String?
    @Published var banner: BannerMessage?
    @Published var isBusy = false
    @Published private var isRefreshingUsage = false

    private var hasBootstrapped = false
    private var oauthTask: Task<Void, Never>?
    private var authSyncTimer: Timer?
    private var usageRefreshTimer: Timer?
    private var observedAuthState: AuthFileState = .missing
    private var ignoredAuthSignature: String?

    let authManager = AuthManager()
    let accountStore = AccountStore()
    let usageService = UsageService()
    let oauthManager = OAuthManager()

    var currentAccount: Account? {
        accounts.first(where: { $0.id == currentAccountID })
    }

    var authFilePath: String {
        authManager.authFileURL.path
    }

    var authFileName: String {
        authManager.authFileURL.lastPathComponent
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true
        do {
            accounts = try accountStore.loadAccounts()
            observedAuthState = try authManager.currentAuthState()
            let syncResult = try syncCurrentAuthIntoStoreIfNeeded()
            currentAccountID = authManager.identifyCurrentAccount(in: accounts)?.id
            if let syncResult {
                banner = syncResult
            }
            startAuthSyncTimer()
            startUsageRefreshTimer()
            refreshAllUsage(silent: true)
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Failed to load accounts", detail: error.localizedDescription, tone: .error)
        }
    }

    func refreshStatus() {
        do {
            if let syncResult = try syncCurrentAuthIntoStoreIfNeeded() {
                banner = syncResult
            }
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Sync failed", detail: error.localizedDescription, tone: .error)
        }
        currentAccountID = authManager.identifyCurrentAccount(in: accounts)?.id
    }

    func refreshAllUsage(silent: Bool = false) {
        guard !accounts.isEmpty else { return }
        guard !isRefreshingUsage else { return }

        if !silent {
            isBusy = true
            banner = nil
        }
        lastError = nil
        isRefreshingUsage = true

        Task {
            defer {
                self.isRefreshingUsage = false
                if !silent { self.isBusy = false }
            }

            let snapshotAccounts = accounts
            var failures: [String] = []

            let results = await withTaskGroup(
                of: (Int, Result<UsageInfo, Error>).self,
                returning: [(Int, Result<UsageInfo, Error>)].self
            ) { group in
                for (index, account) in snapshotAccounts.enumerated() {
                    group.addTask {
                        do {
                            let usage = try await self.usageService.refreshUsage(for: account)
                            return (index, .success(usage))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                }
                var collected: [(Int, Result<UsageInfo, Error>)] = []
                for await result in group {
                    collected.append(result)
                }
                return collected
            }

            var updatedAccountsByID: [String: Account] = [:]
            for (index, result) in results {
                guard snapshotAccounts.indices.contains(index) else { continue }
                var updatedAccount = snapshotAccounts[index]
                switch result {
                case .success(let usage):
                    updatedAccount.usage = usage
                    updatedAccount.planType = usage.planType ?? updatedAccount.planType
                    updatedAccount.usageError = nil
                    updatedAccount.updatedAt = Date()
                case .failure(let error):
                    updatedAccount.usageError = error.localizedDescription
                    failures.append(updatedAccount.email ?? updatedAccount.label)
                }
                updatedAccountsByID[updatedAccount.id] = updatedAccount
            }

            var didApplyUsageUpdate = false
            accounts = accounts.map { account in
                guard let updatedAccount = updatedAccountsByID[account.id] else {
                    return account
                }
                didApplyUsageUpdate = true
                return updatedAccount
            }

            guard didApplyUsageUpdate else { return }

            persistAccounts()
            autoSwitchIfNeeded()

            if banner?.title == "Automatically switched account" || banner?.title == "Usage limit reached" {
                return
            }

            if failures.isEmpty {
                banner = BannerMessage(
                    title: "Usage refreshed",
                    detail: "Updated \(updatedAccountsByID.count) account(s).",
                    tone: .success
                )
            } else {
                banner = BannerMessage(
                    title: "Usage refresh finished with issues",
                    detail: "\(failures.count) account(s) could not be updated.",
                    tone: .warning
                )
            }
        }
    }

    func switchAccount(_ account: Account) {
        guard !isBusy else { return }

        isBusy = true
        lastError = nil

        Task {
            defer { self.isBusy = false }

            do {
                let usage = try await usageService.refreshUsage(for: account)
                guard let index = accounts.firstIndex(where: { $0.id == account.id }) else { return }

                accounts[index].usage = usage
                accounts[index].planType = usage.planType ?? accounts[index].planType
                accounts[index].usageError = nil
                accounts[index].updatedAt = Date()
                persistAccounts()

                if isExhausted(accounts[index]) {
                    banner = BannerMessage(
                        title: "Cannot switch to exhausted account",
                        detail: "\(accounts[index].email ?? accounts[index].label) is already at its usage limit.",
                        tone: .warning
                    )
                    autoSwitchIfNeeded()
                    return
                }

                activateAccount(
                    accounts[index],
                    title: "Account switched",
                    detail: "Now using \(accounts[index].email ?? accounts[index].label).",
                    tone: .success,
                    manageBusyState: false
                )

                refreshAllUsage(silent: true)
            } catch {
                lastError = error.localizedDescription
                banner = BannerMessage(
                    title: "Switch precheck failed",
                    detail: error.localizedDescription,
                    tone: .error
                )
            }
        }
    }

    func importCurrentAuth() {
        isBusy = true
        defer { isBusy = false }

        do {
            let imported = try accountStore.importCurrentAuth(label: nil, authManager: authManager)
            let outcome = try saveImportedAccount(imported)
            refreshStatus()
            lastError = nil
            banner = bannerForImportOutcome(outcome, source: "Current Codex auth")
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Import failed", detail: error.localizedDescription, tone: .error)
        }
    }

    func startOAuthLogin() {
        isBusy = true
        lastError = nil
        banner = BannerMessage(
            title: "Opening OpenAI login",
            detail: "Your browser session decides which account is returned.",
            tone: .info
        )

        oauthTask = Task {
            do {
                let auth = try await oauthManager.login()
                let imported = accountStore.importedOAuthAccount(from: auth)
                let outcome = try saveImportedAccount(imported)
                refreshStatus()
                banner = bannerForImportOutcome(outcome, source: "OpenAI authorization")
                isBusy = false
            } catch {
                if !Task.isCancelled {
                    lastError = error.localizedDescription
                    banner = BannerMessage(title: "Authorization failed", detail: error.localizedDescription, tone: .error)
                }
                isBusy = false
            }
            oauthTask = nil
        }
    }

    func cancelOAuthLogin() {
        oauthTask?.cancel()
        oauthTask = nil
        isBusy = false
        banner = nil
    }

    func importAuthFile(from url: URL) {
        isBusy = true
        defer { isBusy = false }

        do {
            let imported = try accountStore.importAuthFile(at: url)
            let outcome = try saveImportedAccount(imported)
            refreshStatus()
            lastError = nil
            banner = bannerForImportOutcome(outcome, source: url.lastPathComponent)
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Import failed", detail: error.localizedDescription, tone: .error)
        }
    }

    func updateLabel(for accountID: String, label: String) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else { return }
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        accounts[index].label = trimmed
        accounts[index].updatedAt = Date()
        persistAccounts()
        banner = BannerMessage(title: "Label updated", detail: "Saved display name for this account.", tone: .success)
    }

    func deleteAccount(_ account: Account) {
        if currentAccountID == account.id {
            ignoredAuthSignature = AuthNormalizer.matchSignature(for: account.auth)
        }
        accounts.removeAll(where: { $0.id == account.id })
        if currentAccountID == account.id {
            currentAccountID = nil
        }
        persistAccounts()
        banner = BannerMessage(
            title: "Account removed",
            detail: "Deleted \(account.email ?? account.label) from the saved list.",
            tone: .warning
        )
    }

    func revealStorageInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([accountStore.storeFileURL])
    }

    private func saveImportedAccount(_ imported: Account) throws -> ImportOutcome {
        if let existingIndex = accounts.firstIndex(where: { accountsMatch($0, imported) }) {
            accounts[existingIndex] = mergedAccount(existing: accounts[existingIndex], imported: imported)
            try accountStore.saveAccounts(accounts)
            return .refreshed(accounts[existingIndex])
        } else {
            accounts.insert(imported, at: 0)
            try accountStore.saveAccounts(accounts)
            return .inserted(imported)
        }
    }

    private func persistAccounts() {
        do {
            try accountStore.saveAccounts(accounts)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Save failed", detail: error.localizedDescription, tone: .error)
        }
    }

    private func startAuthSyncTimer() {
        guard authSyncTimer == nil else { return }
        authSyncTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollAuthState()
            }
        }
        authSyncTimer?.tolerance = 0.5
    }

    private func startUsageRefreshTimer() {
        guard usageRefreshTimer == nil else { return }
        usageRefreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAllUsage(silent: true)
            }
        }
        usageRefreshTimer?.tolerance = 10
    }

    private func pollAuthState() {
        do {
            let nextState = try authManager.currentAuthState()
            guard nextState != observedAuthState else { return }
            let previousState = observedAuthState
            observedAuthState = nextState
            syncWithObservedAuthState(previous: previousState, current: nextState)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func syncWithObservedAuthState(previous: AuthFileState, current: AuthFileState) {
        switch (previous, current) {
        case (.present(let oldAuth), .missing):
            if ignoredAuthSignature == AuthNormalizer.matchSignature(for: oldAuth) {
                ignoredAuthSignature = nil
            }
            currentAccountID = authManager.identifyCurrentAccount(in: accounts)?.id
            lastError = nil
            banner = BannerMessage(
                title: "Local Codex logout detected",
                detail: "The current local auth.json disappeared. Saved accounts were kept unchanged.",
                tone: .warning
            )

        case (_, .present):
            do {
                let syncResult = try syncCurrentAuthIntoStoreIfNeeded()
                currentAccountID = authManager.identifyCurrentAccount(in: accounts)?.id
                lastError = nil

                if let syncResult {
                    banner = syncResult
                } else if case .present(let oldAuth) = previous,
                          case .present(let newAuth) = current,
                          !AuthNormalizer.matches(oldAuth, newAuth) {
                    banner = BannerMessage(
                        title: "Local Codex account changed",
                        detail: "Detected an external auth.json update and synced the active account.",
                        tone: .info
                    )
                }
            } catch {
                lastError = error.localizedDescription
                banner = BannerMessage(title: "Sync failed", detail: error.localizedDescription, tone: .error)
            }

        case (.missing, .missing):
            currentAccountID = nil
        }
    }

    private func syncCurrentAuthIntoStoreIfNeeded() throws -> BannerMessage? {
        let imported: Account
        do {
            imported = try accountStore.importCurrentAuth(label: nil, authManager: authManager)
        } catch AppError.noCurrentCodexAuth {
            return nil
        } catch {
            throw error
        }

        if let importedSignature = AuthNormalizer.matchSignature(for: imported.auth),
           importedSignature != ignoredAuthSignature {
            ignoredAuthSignature = nil
        }

        if ignoredAuthSignature == AuthNormalizer.matchSignature(for: imported.auth) {
            currentAccountID = nil
            return nil
        }

        if accounts.contains(where: { accountsMatch($0, imported) }) {
            return nil
        }

        // Preserve the saved account list on startup and background sync.
        // If the current local auth is not already in the list, require an explicit import.
        if accountStore.storeFileExists || !accounts.isEmpty {
            return BannerMessage(
                title: "Current local account not saved",
                detail: "The active ~/.codex/auth.json account is not in your saved list. Use Import Current Auth to add it explicitly.",
                tone: .info
            )
        }

        let outcome = try saveImportedAccount(imported)
        switch outcome {
        case .inserted(let account):
            return BannerMessage(
                title: "Local Codex account imported",
                detail: "\(account.email ?? account.label) was found in ~/.codex/auth.json and added automatically.",
                tone: .info
            )
        case .refreshed:
            return nil
        }
    }

    private func bannerForImportOutcome(_ outcome: ImportOutcome, source: String) -> BannerMessage {
        switch outcome {
        case .inserted(let account):
            return BannerMessage(
                title: "New account added",
                detail: "\(account.email ?? account.label) was imported from \(source).",
                tone: .success
            )
        case .refreshed(let account):
            return BannerMessage(
                title: "Existing account refreshed",
                detail: "\(account.email ?? account.label) was already in your list, so its credentials were updated instead of adding a duplicate.",
                tone: .warning
            )
        }
    }

    private func mergedAccount(existing: Account, imported: Account) -> Account {
        let resolvedLabel: String
        if existing.label.isEmpty || existing.label.hasPrefix("account-") {
            resolvedLabel = imported.email ?? imported.label
        } else {
            resolvedLabel = existing.label
        }

        return Account(
            id: existing.id,
            label: resolvedLabel,
            email: imported.email ?? existing.email,
            accountId: imported.accountId.isEmpty ? existing.accountId : imported.accountId,
            chatGPTAccountId: imported.chatGPTAccountId ?? existing.chatGPTAccountId,
            principalId: imported.principalId ?? existing.principalId,
            planType: imported.planType ?? existing.planType,
            auth: imported.auth,
            addedAt: existing.addedAt,
            updatedAt: Date(),
            usage: existing.usage,
            usageError: existing.usageError
        )
    }

    private func accountsMatch(_ lhs: Account, _ rhs: Account) -> Bool {
        if let lhsID = normalizedIdentity(lhs.chatGPTAccountId ?? lhs.accountId),
           let rhsID = normalizedIdentity(rhs.chatGPTAccountId ?? rhs.accountId),
           lhsID == rhsID {
            return true
        }

        if let lhsPrincipal = normalizedIdentity(lhs.principalId),
           let rhsPrincipal = normalizedIdentity(rhs.principalId),
           lhsPrincipal == rhsPrincipal {
            return true
        }

        if let lhsEmail = normalizedEmail(lhs.email),
           let rhsEmail = normalizedEmail(rhs.email),
           lhsEmail == rhsEmail {
            return true
        }

        let lhsHasStableIdentity =
            normalizedIdentity(lhs.chatGPTAccountId ?? lhs.accountId) != nil ||
            normalizedIdentity(lhs.principalId) != nil ||
            normalizedEmail(lhs.email) != nil
        let rhsHasStableIdentity =
            normalizedIdentity(rhs.chatGPTAccountId ?? rhs.accountId) != nil ||
            normalizedIdentity(rhs.principalId) != nil ||
            normalizedEmail(rhs.email) != nil

        guard !lhsHasStableIdentity, !rhsHasStableIdentity else {
            return false
        }

        return AuthNormalizer.matches(lhs.auth, rhs.auth)
    }

    private func normalizedIdentity(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedEmail(_ value: String?) -> String? {
        normalizedIdentity(value)?.lowercased()
    }

    private func activateAccount(
        _ account: Account,
        title: String,
        detail: String,
        tone: BannerMessage.Tone,
        manageBusyState: Bool = true
    ) {
        if manageBusyState {
            isBusy = true
        }
        defer {
            if manageBusyState {
                isBusy = false
            }
        }

        do {
            try authManager.writeAuth(account.auth)
            observedAuthState = .present(account.auth)
            ignoredAuthSignature = nil
            currentAccountID = account.id
            lastError = nil
            banner = BannerMessage(title: title, detail: detail, tone: tone)
        } catch {
            lastError = error.localizedDescription
            banner = BannerMessage(title: "Switch failed", detail: error.localizedDescription, tone: .error)
        }
    }

    private func autoSwitchIfNeeded() {
        guard let currentAccount,
              isExhausted(currentAccount) else { return }

        guard let replacement = bestAutoSwitchCandidate(excluding: currentAccount.id) else {
            banner = BannerMessage(
                title: "Usage limit reached",
                detail: "The active account is exhausted and no other usable account was found.",
                tone: .warning
            )
            return
        }

        activateAccount(
            replacement,
            title: "Automatically switched account",
            detail: "\(currentAccount.email ?? currentAccount.label) reached its limit, so the app moved to \(replacement.email ?? replacement.label).",
            tone: .warning
        )
    }

    private func bestAutoSwitchCandidate(excluding accountID: String) -> Account? {
        accounts
            .filter { $0.id != accountID && isUsable($0) }
            .sorted { lhs, rhs in
                usageRank(for: lhs) < usageRank(for: rhs)
            }
            .first
    }

    private func usageRank(for account: Account) -> Double {
        let fiveHour = account.usage?.fiveHour?.usedPercent ?? 100
        let oneWeek = account.usage?.oneWeek?.usedPercent ?? 100
        return fiveHour + oneWeek
    }

    private func isUsable(_ account: Account) -> Bool {
        guard account.usage != nil else { return false }
        guard AuthNormalizer.accessToken(in: account.auth)?.isEmpty == false else { return false }
        return !isExhausted(account)
    }

    private func isExhausted(_ account: Account) -> Bool {
        if let fiveHour = account.usage?.fiveHour?.usedPercent,
           fiveHour >= 100 {
            return true
        }

        if let oneWeek = account.usage?.oneWeek?.usedPercent,
           oneWeek >= 100 {
            return true
        }

        return false
    }
}
