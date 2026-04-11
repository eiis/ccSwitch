import Foundation

struct UsageService {
    private let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func refreshUsage(for account: Account) async throws -> UsageInfo {
        guard let accessToken = AuthNormalizer.accessToken(in: account.auth), !accessToken.isEmpty else {
            throw AppError.missingCredential("This account does not have an access token.")
        }

        guard let accountID = account.chatGPTAccountId ?? AuthNormalizer.chatGPTAccountID(in: account.auth), !accountID.isEmpty else {
            throw AppError.missingCredential("This account does not have a ChatGPT account ID.")
        }

        var request = URLRequest(url: usageURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.apiError(0, "Usage API returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data.prefix(200), encoding: .utf8) ?? "Unknown error"
            throw AppError.apiError(httpResponse.statusCode, message)
        }

        let payload = try JSONDecoder().decode(UsageAPIResponse.self, from: data)
        let windows = [payload.rateLimit?.primaryWindow, payload.rateLimit?.secondaryWindow].compactMap { $0 }

        let fiveHour = pickNearest(windows, targetSeconds: 5 * 60 * 60).map(toWindow)
        let oneWeek = pickNearest(windows, targetSeconds: 7 * 24 * 60 * 60).map(toWindow)

        return UsageInfo(
            planType: payload.planType,
            fiveHour: fiveHour,
            oneWeek: oneWeek,
            credits: payload.credits.map {
                UsageCredits(hasCredits: $0.hasCredits, unlimited: $0.unlimited, balance: $0.balance)
            },
            fetchedAt: Date()
        )
    }

    private func pickNearest(_ windows: [UsageWindowPayload], targetSeconds: Int) -> UsageWindowPayload? {
        guard let best = windows.min(by: {
            abs($0.limitWindowSeconds - targetSeconds) < abs($1.limitWindowSeconds - targetSeconds)
        }) else { return nil }

        let maxAllowedDrift = Double(targetSeconds) * 0.4
        return Double(abs(best.limitWindowSeconds - targetSeconds)) <= maxAllowedDrift ? best : nil
    }

    private func toWindow(_ raw: UsageWindowPayload) -> UsageWindow {
        UsageWindow(
            usedPercent: raw.usedPercent,
            windowSeconds: raw.limitWindowSeconds,
            resetAt: Date(timeIntervalSince1970: TimeInterval(raw.resetAt))
        )
    }
}

private struct UsageAPIResponse: Decodable {
    let planType: String?
    let rateLimit: RateLimitPayload?
    let credits: CreditsPayload?

    enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case rateLimit = "rate_limit"
        case credits
    }
}

private struct RateLimitPayload: Decodable {
    let primaryWindow: UsageWindowPayload?
    let secondaryWindow: UsageWindowPayload?

    enum CodingKeys: String, CodingKey {
        case primaryWindow = "primary_window"
        case secondaryWindow = "secondary_window"
    }
}

private struct UsageWindowPayload: Decodable {
    let usedPercent: Double
    let limitWindowSeconds: Int
    let resetAt: Int

    enum CodingKeys: String, CodingKey {
        case usedPercent = "used_percent"
        case limitWindowSeconds = "limit_window_seconds"
        case resetAt = "reset_at"
    }
}

private struct CreditsPayload: Decodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?

    enum CodingKeys: String, CodingKey {
        case hasCredits = "has_credits"
        case unlimited
        case balance
    }
}
