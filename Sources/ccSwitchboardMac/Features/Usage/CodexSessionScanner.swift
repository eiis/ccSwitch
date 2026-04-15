import Foundation

// One delta observation from a Codex rollout jsonl.
struct CodexTokenDelta: Sendable {
    let timestamp: Date
    let model: String
    let inputTokens: Int
    let cachedInputTokens: Int
    let outputTokens: Int
    let totalTokens: Int
}

enum CodexSessionScanner {
    static var sessionsRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    // Scan all jsonl files whose directory date is >= `since`. Returns every
    // per-turn token delta with its timestamp, so callers can bucket freely.
    static func scanDeltas(since: Date) -> [CodexTokenDelta] {
        let fm = FileManager.default
        let root = sessionsRoot
        guard fm.fileExists(atPath: root.path) else { return [] }

        let calendar = Calendar(identifier: .gregorian)
        let sinceDay = calendar.startOfDay(for: since)

        var results: [CodexTokenDelta] = []
        let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "jsonl" else { continue }
            if let fileDate = dayFromPath(url), fileDate < sinceDay { continue }
            if let mtime = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
               mtime < since { continue }
            results.append(contentsOf: parseFile(url))
        }
        return results.filter { $0.timestamp >= since }
    }

    // Codex path shape: .../sessions/YYYY/MM/DD/rollout-*.jsonl
    private static func dayFromPath(_ url: URL) -> Date? {
        let parts = url.pathComponents
        guard parts.count >= 4 else { return nil }
        let day = parts[parts.count - 2]
        let month = parts[parts.count - 3]
        let year = parts[parts.count - 4]
        var components = DateComponents()
        components.year = Int(year)
        components.month = Int(month)
        components.day = Int(day)
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private static func parseFile(_ url: URL) -> [CodexTokenDelta] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return [] }

        var currentModel = "unknown"
        var deltas: [CodexTokenDelta] = []

        data.withUnsafeBytes { _ in } // keep data alive
        let newline = UInt8(ascii: "\n")
        var lineStart = data.startIndex
        let end = data.endIndex

        while lineStart < end {
            var lineEnd = lineStart
            while lineEnd < end && data[lineEnd] != newline { lineEnd = data.index(after: lineEnd) }
            let lineData = data[lineStart..<lineEnd]
            lineStart = lineEnd < end ? data.index(after: lineEnd) : end
            guard !lineData.isEmpty else { continue }

            guard let obj = try? JSONSerialization.jsonObject(with: lineData, options: []) as? [String: Any] else {
                continue
            }
            guard let type = obj["type"] as? String else { continue }

            if type == "turn_context",
               let payload = obj["payload"] as? [String: Any],
               let model = payload["model"] as? String,
               !model.isEmpty {
                currentModel = model
                continue
            }

            if type == "event_msg",
               let payload = obj["payload"] as? [String: Any],
               (payload["type"] as? String) == "token_count",
               let info = payload["info"] as? [String: Any],
               let last = info["last_token_usage"] as? [String: Any] {

                let timestamp = parseTimestamp(obj["timestamp"]) ?? Date()
                let input = (last["input_tokens"] as? Int) ?? 0
                let cached = (last["cached_input_tokens"] as? Int) ?? 0
                let output = (last["output_tokens"] as? Int) ?? 0
                let reasoning = (last["reasoning_output_tokens"] as? Int) ?? 0
                let total = (last["total_tokens"] as? Int) ?? (input + output + reasoning)

                // Skip empty deltas — Codex emits periodic zeros.
                if input == 0 && output == 0 && reasoning == 0 { continue }

                deltas.append(CodexTokenDelta(
                    timestamp: timestamp,
                    model: currentModel,
                    inputTokens: input,
                    cachedInputTokens: cached,
                    outputTokens: output + reasoning,
                    totalTokens: total
                ))
            }
        }
        return deltas
    }

    private static func parseTimestamp(_ raw: Any?) -> Date? {
        guard let s = raw as? String else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
