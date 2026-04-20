import Foundation

struct AccountSwitchEntry: Codable, Sendable {
    let timestamp: Date
    let accountID: String
    let label: String
}

// Append-only log of "when did which account become active".
// Used to attribute Codex session token usage to individual accounts
// for events that happened AFTER a switch we observed.
final class AccountSwitchLog: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let lock = NSLock()

    private var appSupportDirectoryURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ccSwitchboardMac", isDirectory: true)
    }

    var fileURL: URL {
        appSupportDirectoryURL.appendingPathComponent("account-switch-log.json")
    }

    func load() -> [AccountSwitchEntry] {
        lock.lock()
        defer { lock.unlock() }
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder.app.decode([AccountSwitchEntry].self, from: data)
        else { return [] }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }

    func append(accountID: String, label: String, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        var entries = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder.app.decode([AccountSwitchEntry].self, from: $0) } ?? []
        if let last = entries.last, last.accountID == accountID {
            return // dedupe consecutive
        }
        entries.append(AccountSwitchEntry(timestamp: date, accountID: accountID, label: label))
        try? fileManager.createDirectory(at: appSupportDirectoryURL, withIntermediateDirectories: true)
        if let data = try? JSONEncoder.pretty.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // Returns the account ID that was active at `date`, or nil if unknown.
    func accountID(at date: Date, in entries: [AccountSwitchEntry]) -> String? {
        var active: String?
        for e in entries {
            if e.timestamp <= date { active = e.accountID } else { break }
        }
        return active
    }
}
