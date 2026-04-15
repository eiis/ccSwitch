import Foundation

struct CodexModelPrice {
    let input: Double
    let cachedInput: Double
    let output: Double
}

enum CodexPricing {
    // USD per 1M tokens. Hand-maintained; unknown models fall through to nil.
    private static let table: [String: CodexModelPrice] = [
        "gpt-5":           CodexModelPrice(input: 1.25, cachedInput: 0.125, output: 10.00),
        "gpt-5-mini":      CodexModelPrice(input: 0.25, cachedInput: 0.025, output: 2.00),
        "gpt-5-nano":      CodexModelPrice(input: 0.05, cachedInput: 0.005, output: 0.40),
        "gpt-5.1":         CodexModelPrice(input: 1.25, cachedInput: 0.125, output: 10.00),
        "gpt-5.1-mini":    CodexModelPrice(input: 0.25, cachedInput: 0.025, output: 2.00),
        "gpt-5.2":         CodexModelPrice(input: 1.25, cachedInput: 0.125, output: 10.00),
        "gpt-5.3":         CodexModelPrice(input: 1.25, cachedInput: 0.125, output: 10.00),
        "gpt-5.4":         CodexModelPrice(input: 1.25, cachedInput: 0.125, output: 10.00),
        "gpt-4.1":         CodexModelPrice(input: 2.00, cachedInput: 0.50,  output: 8.00),
        "gpt-4.1-mini":    CodexModelPrice(input: 0.40, cachedInput: 0.10,  output: 1.60),
        "o3":              CodexModelPrice(input: 2.00, cachedInput: 0.50,  output: 8.00),
        "o4-mini":         CodexModelPrice(input: 1.10, cachedInput: 0.275, output: 4.40)
    ]

    static func price(for model: String) -> CodexModelPrice? {
        if let exact = table[model] { return exact }
        let lowered = model.lowercased()
        if let exact = table[lowered] { return exact }
        // Strip trailing variants like "-2025-01-01"
        if let dash = lowered.firstIndex(of: "-") {
            var prefix = String(lowered[..<dash])
            if let hit = table[prefix] { return hit }
            // Try two-segment prefix (e.g. "gpt-5-mini")
            let rest = lowered[lowered.index(after: dash)...]
            if let nextDash = rest.firstIndex(of: "-") {
                prefix = String(lowered[..<nextDash])
                if let hit = table[prefix] { return hit }
            }
        }
        return nil
    }

    static func cost(
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        model: String
    ) -> Double? {
        guard let p = price(for: model) else { return nil }
        let uncachedInput = max(inputTokens - cachedInputTokens, 0)
        let million = 1_000_000.0
        let inCost = Double(uncachedInput) / million * p.input
        let cachedCost = Double(cachedInputTokens) / million * p.cachedInput
        let outCost = Double(outputTokens) / million * p.output
        return inCost + cachedCost + outCost
    }
}
