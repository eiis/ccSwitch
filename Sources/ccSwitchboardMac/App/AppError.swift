import Foundation

enum AppError: LocalizedError {
    case noCurrentCodexAuth
    case invalidAuthFile
    case missingCredential(String)
    case apiError(Int, String)
    case oauthFlowFailed(String)

    var errorDescription: String? {
        switch self {
        case .noCurrentCodexAuth:
            return "No ~/.codex/auth.json was found."
        case .invalidAuthFile:
            return "The selected file is not a valid Codex auth JSON."
        case .missingCredential(let message):
            return message
        case .apiError(let statusCode, let message):
            return "API error \(statusCode): \(message)"
        case .oauthFlowFailed(let message):
            return message
        }
    }
}
