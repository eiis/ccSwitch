import Foundation

struct Account: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var label: String
    var email: String?
    var accountId: String
    var chatGPTAccountId: String?
    var principalId: String?
    var planType: String?
    var auth: [String: JSONValue]
    var addedAt: Date
    var updatedAt: Date
    var usage: UsageInfo?
    var usageError: String?
}

struct UsageInfo: Codable, Equatable, Sendable {
    var planType: String?
    var fiveHour: UsageWindow?
    var oneWeek: UsageWindow?
    var credits: UsageCredits?
    var fetchedAt: Date
}

struct UsageWindow: Codable, Equatable, Sendable {
    var usedPercent: Double
    var windowSeconds: Int
    var resetAt: Date
}

struct UsageCredits: Codable, Equatable, Sendable {
    var hasCredits: Bool
    var unlimited: Bool
    var balance: String?
}

struct AccountStoreSnapshot: Codable {
    var version: Int
    var accounts: [Account]
}
