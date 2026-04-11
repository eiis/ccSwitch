import Foundation

struct AccountStore {
    private let fileManager = FileManager.default

    var appSupportDirectoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ccSwitchboardMac", isDirectory: true)
    }

    var storeFileURL: URL {
        appSupportDirectoryURL.appendingPathComponent("accounts.json")
    }

    var storeFileExists: Bool {
        fileManager.fileExists(atPath: storeFileURL.path)
    }

    func loadAccounts() throws -> [Account] {
        guard fileManager.fileExists(atPath: storeFileURL.path) else { return [] }
        let data = try Data(contentsOf: storeFileURL)
        let snapshot = try JSONDecoder.app.decode(AccountStoreSnapshot.self, from: data)
        return snapshot.accounts.sorted(by: { $0.addedAt > $1.addedAt })
    }

    func saveAccounts(_ accounts: [Account]) throws {
        try fileManager.createDirectory(at: appSupportDirectoryURL, withIntermediateDirectories: true)
        let snapshot = AccountStoreSnapshot(version: 1, accounts: accounts)
        let data = try JSONEncoder.pretty.encode(snapshot)
        let tempURL = storeFileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: storeFileURL.path) {
            let backupURL = storeFileURL.appendingPathExtension("backup")
            _ = try? fileManager.removeItem(at: backupURL)
            try fileManager.copyItem(at: storeFileURL, to: backupURL)
            _ = try fileManager.replaceItemAt(storeFileURL, withItemAt: tempURL)
            return
        }

        try fileManager.moveItem(at: tempURL, to: storeFileURL)
    }

    func importCurrentAuth(label: String?, authManager: AuthManager) throws -> Account {
        guard let auth = try authManager.readCurrentAuth() else {
            throw AppError.noCurrentCodexAuth
        }
        return makeImportedAccount(from: auth, label: label)
    }

    func importAuthFile(at url: URL, label: String? = nil) throws -> Account {
        let data = try Data(contentsOf: url)
        let auth = try JSONDecoder.app.decode([String: JSONValue].self, from: data)
        return makeImportedAccount(from: auth, label: label)
    }

    func importedOAuthAccount(from auth: [String: JSONValue], label: String? = nil) -> Account {
        makeImportedAccount(from: auth, label: label)
    }

    private func makeImportedAccount(from auth: [String: JSONValue], label: String?) -> Account {
        let metadata = AccountMetadataExtractor.extract(from: auth)
        let now = Date()
        return Account(
            id: "acc_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased())",
            label: label ?? metadata.fallbackLabel,
            email: metadata.email,
            accountId: metadata.accountId,
            chatGPTAccountId: metadata.chatGPTAccountId,
            principalId: metadata.principalId,
            planType: metadata.planType,
            auth: AuthNormalizer.normalize(auth),
            addedAt: now,
            updatedAt: now,
            usage: nil,
            usageError: nil
        )
    }
}

enum AccountMetadataExtractor {
    static func extract(from auth: [String: JSONValue]) -> (email: String?, accountId: String, principalId: String?, planType: String?, chatGPTAccountId: String?, fallbackLabel: String) {
        let rootEmail = auth["email"]?.stringValue
        let tokens = AuthNormalizer.tokenRecord(from: auth)
        let idToken = tokens["id_token"]?.stringValue ?? auth["id_token"]?.stringValue
        let decoded = idToken.flatMap(decodeIDToken)
        let authPayload = decoded?.openAIAuth

        let email = rootEmail ?? decoded?.email
        let accountId =
            tokens["account_id"]?.stringValue ??
            auth["account_id"]?.stringValue ??
            auth["accountId"]?.stringValue ??
            authPayload?.chatGPTAccountID ??
            ""
        let principalId =
            auth["principal_id"]?.stringValue ??
            authPayload?.chatGPTUserID
        let planType =
            auth["plan_type"]?.stringValue ??
            authPayload?.chatGPTPlanType

        let label = email ?? "account-\(Int(Date().timeIntervalSince1970))"
        return (email, accountId, principalId, planType, accountId.isEmpty ? nil : accountId, label)
    }

    private static func decodeIDToken(_ jwt: String) -> IDTokenPayload? {
        JWTDecoder.decodePayload(jwt, as: IDTokenPayload.self)
    }
}
