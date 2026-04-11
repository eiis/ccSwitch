import Foundation

enum AuthNormalizer {
    static func normalize(_ auth: [String: JSONValue]) -> [String: JSONValue] {
        var root = auth
        var tokens = tokenRecord(from: auth)

        if let accessToken = tokens["access_token"] {
            root.removeValue(forKey: "access_token")
            tokens["access_token"] = accessToken
        }

        if let refreshToken = tokens["refresh_token"] {
            root.removeValue(forKey: "refresh_token")
            tokens["refresh_token"] = refreshToken
        }

        if let idToken = tokens["id_token"] {
            root.removeValue(forKey: "id_token")
            tokens["id_token"] = idToken
        }

        if let accountId = tokens["account_id"] {
            root.removeValue(forKey: "account_id")
            root.removeValue(forKey: "accountId")
            tokens["account_id"] = accountId
        }

        if root["auth_mode"] == nil {
            root["auth_mode"] = .string("chatgpt")
        }

        if root["OPENAI_API_KEY"] == nil {
            root["OPENAI_API_KEY"] = .null
        }

        if root["last_refresh"] == nil {
            let iso8601 = ISO8601DateFormatter().string(from: Date())
            root["last_refresh"] = .string(iso8601)
        }

        root["tokens"] = .object(tokens)
        return root
    }

    static func tokenRecord(from auth: [String: JSONValue]) -> [String: JSONValue] {
        if case .object(let nested)? = auth["tokens"] {
            return nested
        }
        return auth
    }

    static func token(_ key: String, in auth: [String: JSONValue]) -> String? {
        tokenRecord(from: auth)[key]?.stringValue
    }

    static func accessToken(in auth: [String: JSONValue]) -> String? {
        token("access_token", in: auth)
    }

    static func chatGPTAccountID(in auth: [String: JSONValue]) -> String? {
        token("account_id", in: auth) ?? auth["account_id"]?.stringValue ?? auth["accountId"]?.stringValue
    }

    static func matches(_ lhs: [String: JSONValue], _ rhs: [String: JSONValue]) -> Bool {
        let keys = ["refresh_token", "access_token", "id_token"]
        return keys.contains { key in
            guard let left = token(key, in: lhs), let right = token(key, in: rhs) else { return false }
            return left == right
        }
    }

    static func matchSignature(for auth: [String: JSONValue]) -> String? {
        let keys = ["refresh_token", "access_token", "id_token"]
        for key in keys {
            if let value = token(key, in: auth), !value.isEmpty {
                return "\(key):\(value)"
            }
        }
        return nil
    }
}
