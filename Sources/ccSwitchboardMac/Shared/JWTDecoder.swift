import Foundation

enum JWTDecoder {
    static func decodePayload<T: Decodable>(_ jwt: String, as type: T.Type) -> T? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }

        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (payload.count % 4)
        if padding < 4 {
            payload += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: payload) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

struct IDTokenPayload: Decodable {
    let email: String?
    let openAIAuth: OpenAIAuthPayload?

    enum CodingKeys: String, CodingKey {
        case email
        case openAIAuth = "https://api.openai.com/auth"
    }
}

struct OpenAIAuthPayload: Decodable {
    let chatGPTPlanType: String?
    let chatGPTAccountID: String?
    let chatGPTUserID: String?

    enum CodingKeys: String, CodingKey {
        case chatGPTPlanType = "chatgpt_plan_type"
        case chatGPTAccountID = "chatgpt_account_id"
        case chatGPTUserID = "chatgpt_user_id"
    }
}
