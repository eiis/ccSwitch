import Foundation

enum AuthFileState: Equatable {
    case missing
    case present([String: JSONValue])
}

struct AuthManager {
    private let fileManager = FileManager.default

    var codexDirectoryURL: URL {
        fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".codex", isDirectory: true)
    }

    var authFileURL: URL {
        codexDirectoryURL.appendingPathComponent("auth.json")
    }

    func currentAuthState() throws -> AuthFileState {
        guard fileManager.fileExists(atPath: authFileURL.path) else { return .missing }
        let data = try Data(contentsOf: authFileURL)
        let auth = try JSONDecoder().decode([String: JSONValue].self, from: data)
        return .present(auth)
    }

    func readCurrentAuth() throws -> [String: JSONValue]? {
        switch try currentAuthState() {
        case .missing:
            return nil
        case .present(let auth):
            return auth
        }
    }

    func identifyCurrentAccount(in accounts: [Account]) -> Account? {
        do {
            guard let currentAuth = try readCurrentAuth() else { return nil }
            return accounts.first(where: { AuthNormalizer.matches($0.auth, currentAuth) })
        } catch {
            return nil
        }
    }

    func writeAuth(_ auth: [String: JSONValue]) throws {
        let normalized = AuthNormalizer.normalize(auth)
        try fileManager.createDirectory(at: codexDirectoryURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: authFileURL.path) {
            let backupURL = authFileURL.appendingPathExtension("backup")
            _ = try? fileManager.removeItem(at: backupURL)
            try fileManager.copyItem(at: authFileURL, to: backupURL)
        }

        let tempURL = authFileURL.appendingPathExtension("tmp")
        let data = try JSONEncoder.pretty.encode(normalized)
        try data.write(to: tempURL, options: .atomic)

        if fileManager.fileExists(atPath: authFileURL.path) {
            _ = try? fileManager.removeItem(at: authFileURL)
        }
        try fileManager.moveItem(at: tempURL, to: authFileURL)
    }
}
