import Foundation

struct TokenUsageBucket: Equatable {
    var inputTokens: Int = 0
    var cachedInputTokens: Int = 0
    var outputTokens: Int = 0
    var totalTokens: Int = 0
    var costUSD: Double = 0
    var hasUnknownModel: Bool = false

    mutating func add(_ d: CodexTokenDelta) {
        inputTokens += d.inputTokens
        cachedInputTokens += d.cachedInputTokens
        outputTokens += d.outputTokens
        totalTokens += d.totalTokens
        if let c = CodexPricing.cost(
            inputTokens: d.inputTokens,
            cachedInputTokens: d.cachedInputTokens,
            outputTokens: d.outputTokens,
            model: d.model
        ) {
            costUSD += c
        } else {
            hasUnknownModel = true
        }
    }
}

struct TokenUsageSummary: Equatable {
    var today: TokenUsageBucket
    var sevenDays: TokenUsageBucket
    var month: TokenUsageBucket
    // Per-account attributed buckets, keyed by account id. Month scope.
    var perAccountMonth: [String: TokenUsageBucket]
    var fetchedAt: Date

    static let empty = TokenUsageSummary(
        today: .init(),
        sevenDays: .init(),
        month: .init(),
        perAccountMonth: [:],
        fetchedAt: .distantPast
    )
}

@MainActor
final class TokenUsageStore: ObservableObject {
    @Published private(set) var summary: TokenUsageSummary = .empty
    @Published private(set) var isRefreshing = false

    private let switchLog: AccountSwitchLog
    private var refreshTask: Task<Void, Never>?

    init(switchLog: AccountSwitchLog) {
        self.switchLog = switchLog
    }

    func refresh() {
        if refreshTask != nil { return }
        isRefreshing = true
        let log = switchLog
        refreshTask = Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                Self.computeSummary(switchLog: log)
            }.value
            guard let self else { return }
            self.summary = result
            self.isRefreshing = false
            self.refreshTask = nil
        }
    }

    nonisolated private static func computeSummary(switchLog: AccountSwitchLog) -> TokenUsageSummary {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: now)
        let startOf7d = calendar.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
        let startOfMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? startOfToday

        let earliest = min(startOf7d, startOfMonth)
        let deltas = CodexSessionScanner.scanDeltas(since: earliest)
        let switches = switchLog.load()

        var today = TokenUsageBucket()
        var week = TokenUsageBucket()
        var month = TokenUsageBucket()
        var perAccount: [String: TokenUsageBucket] = [:]

        for d in deltas {
            if d.timestamp >= startOfMonth {
                month.add(d)
                if let acct = switchLog.accountID(at: d.timestamp, in: switches) {
                    var bucket = perAccount[acct] ?? TokenUsageBucket()
                    bucket.add(d)
                    perAccount[acct] = bucket
                }
            }
            if d.timestamp >= startOf7d { week.add(d) }
            if d.timestamp >= startOfToday { today.add(d) }
        }

        return TokenUsageSummary(
            today: today,
            sevenDays: week,
            month: month,
            perAccountMonth: perAccount,
            fetchedAt: now
        )
    }
}
