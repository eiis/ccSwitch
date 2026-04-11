import AppKit
import CryptoKit
import Foundation
import Network

struct OAuthManager {
    private let authEndpoint = URL(string: "https://auth.openai.com/oauth/authorize")!
    private let tokenEndpoint = URL(string: "https://auth.openai.com/oauth/token")!
    private let clientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    private let redirectPort: UInt16 = 1455

    func login() async throws -> [String: JSONValue] {
        let codeVerifier = Self.base64URL(Data((0..<32).map { _ in UInt8.random(in: 0...255) }))
        let codeChallenge = Self.base64URL(Data(SHA256.hash(data: Data(codeVerifier.utf8))))
        let state = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let redirectURL = URL(string: "http://localhost:\(redirectPort)/auth/callback")!

        let callback = try await waitForCallback(state: state, redirectURL: redirectURL) { listenerReady in
            let authURL = self.makeAuthorizeURL(
                state: state,
                redirectURL: redirectURL,
                codeChallenge: codeChallenge
            )
            listenerReady()
            NSWorkspace.shared.open(authURL)
        }

        let tokens = try await exchangeCode(
            code: callback.code,
            codeVerifier: codeVerifier,
            redirectURL: redirectURL
        )

        return makeAuthDictionary(tokens: tokens)
    }

    private func makeAuthorizeURL(state: String, redirectURL: URL, codeChallenge: String) -> URL {
        var components = URLComponents(url: authEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURL.absoluteString),
            URLQueryItem(name: "scope", value: "openid profile email offline_access api.connectors.read api.connectors.invoke"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "id_token_add_organizations", value: "true"),
            URLQueryItem(name: "codex_cli_simplified_flow", value: "true"),
            URLQueryItem(name: "originator", value: "codex_cli_rs")
        ]
        return components.url!
    }

    private func exchangeCode(code: String, codeVerifier: String, redirectURL: URL) async throws -> OAuthTokens {
        var request = URLRequest(url: tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type": "authorization_code",
            "client_id": clientID,
            "code": code,
            "redirect_uri": redirectURL.absoluteString,
            "code_verifier": codeVerifier
        ]

        request.httpBody = body
            .map { key, value in
                "\(Self.formEncode(key))=\(Self.formEncode(value))"
            }
            .sorted()
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.oauthFlowFailed("OAuth token exchange returned an invalid response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data.prefix(200), encoding: .utf8) ?? "Unknown error"
            throw AppError.oauthFlowFailed("OAuth token exchange failed: \(httpResponse.statusCode) \(message)")
        }

        return try JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    private func makeAuthDictionary(tokens: OAuthTokens) -> [String: JSONValue] {
        var auth: [String: JSONValue] = [
            "access_token": .string(tokens.accessToken),
            "token_type": .string(tokens.tokenType),
            "expires_in": .number(Double(tokens.expiresIn))
        ]

        if let refreshToken = tokens.refreshToken {
            auth["refresh_token"] = .string(refreshToken)
        }

        if let idToken = tokens.idToken {
            auth["id_token"] = .string(idToken)
            if let payload = decodeJWT(idToken) {
                if let email = payload.email {
                    auth["email"] = .string(email)
                }
                if let openAIAuth = payload.openAIAuth {
                    if let accountID = openAIAuth.chatGPTAccountID {
                        auth["account_id"] = .string(accountID)
                    }
                    if let planType = openAIAuth.chatGPTPlanType {
                        auth["plan_type"] = .string(planType)
                    }
                    if let userID = openAIAuth.chatGPTUserID {
                        auth["principal_id"] = .string(userID)
                    }
                }
            }
        }

        return AuthNormalizer.normalize(auth)
    }

    private func decodeJWT(_ jwt: String) -> IDTokenPayload? {
        JWTDecoder.decodePayload(jwt, as: IDTokenPayload.self)
    }

    private func waitForCallback(
        state: String,
        redirectURL: URL,
        onReady: @escaping @Sendable (@escaping () -> Void) -> Void
    ) async throws -> OAuthCallback {
        let port = NWEndpoint.Port(rawValue: redirectPort)!
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: port)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let queue = DispatchQueue(label: "ccswitchboard.oauth.listener")
                let resumeBox = ResumeBox()

                @Sendable func resume(_ result: Result<OAuthCallback, Error>) {
                    guard resumeBox.markIfNeeded() else { return }
                    listener.cancel()
                    continuation.resume(with: result)
                }

                listener.stateUpdateHandler = { newState in
                    switch newState {
                    case .ready:
                        onReady({})
                    case .failed(let error):
                        resume(.failure(AppError.oauthFlowFailed("OAuth listener failed: \(error.localizedDescription)")))
                    default:
                        break
                    }
                }

                listener.newConnectionHandler = { connection in
                    connection.start(queue: queue)
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                        if let error {
                            connection.cancel()
                            resume(.failure(AppError.oauthFlowFailed("OAuth callback failed: \(error.localizedDescription)")))
                            return
                        }

                        guard let data, let request = String(data: data, encoding: .utf8) else {
                            connection.cancel()
                            resume(.failure(AppError.oauthFlowFailed("OAuth callback returned an unreadable response.")))
                            return
                        }

                        let line = request.components(separatedBy: "\r\n").first ?? ""
                        let path = line.components(separatedBy: " ").dropFirst().first ?? ""
                        guard let callbackURL = URL(string: String(path), relativeTo: redirectURL.deletingLastPathComponent()) else {
                            Self.sendHTMLResponse(connection: connection, title: "Error", message: "Invalid callback URL")
                            resume(.failure(AppError.oauthFlowFailed("OAuth callback URL was invalid.")))
                            return
                        }

                        let components = URLComponents(url: callbackURL.absoluteURL, resolvingAgainstBaseURL: true)
                        if let returnedState = components?.queryItems?.first(where: { $0.name == "state" })?.value,
                           let code = components?.queryItems?.first(where: { $0.name == "code" })?.value,
                           returnedState == state {
                            Self.sendHTMLResponse(connection: connection, title: "Login Successful", message: "Account added. You can close this tab.")
                            resume(.success(OAuthCallback(code: code, state: returnedState)))
                            return
                        }

                        let errorDescription = components?.queryItems?.first(where: { $0.name == "error_description" })?.value
                        Self.sendHTMLResponse(connection: connection, title: "Login Failed", message: errorDescription ?? "State mismatch. Please try again.")
                        resume(.failure(AppError.oauthFlowFailed(errorDescription ?? "OAuth state mismatch.")))
                    }
                }

                listener.start(queue: queue)

                queue.asyncAfter(deadline: .now() + 120) {
                    resume(.failure(AppError.oauthFlowFailed("OAuth login timed out after 2 minutes.")))
                }
            }
        } onCancel: {
            listener.cancel()
        }
    }

    private static func htmlEscape(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;")
              .replacingOccurrences(of: "<", with: "&lt;")
              .replacingOccurrences(of: ">", with: "&gt;")
              .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func sendHTMLResponse(connection: NWConnection, title: String, message: String) {
        let safeTitle = htmlEscape(title)
        let safeMessage = htmlEscape(message)
        let html = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8" />
        <title>\(safeTitle)</title>
        <style>
        body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #f4f8fb; display:flex; align-items:center; justify-content:center; height:100vh; margin:0; }
        .card { background:white; padding: 28px; border-radius: 18px; box-shadow: 0 16px 48px rgba(15,23,42,0.12); max-width: 420px; text-align:center; }
        h2 { margin: 0 0 8px 0; }
        p { margin: 0; color: #475569; }
        </style>
        </head>
        <body><div class="card"><h2>\(safeTitle)</h2><p>\(safeMessage)</p></div></body>
        </html>
        """

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """

        connection.send(content: response.data(using: .utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }

    private static func formEncode(_ string: String) -> String {
        string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&=?"))) ?? string
    }

}

private struct OAuthCallback {
    let code: String
    let state: String
}

private final class ResumeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func markIfNeeded() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !resumed else { return false }
        resumed = true
        return true
    }
}

private struct OAuthTokens: Decodable {
    let accessToken: String
    let refreshToken: String?
    let idToken: String?
    let tokenType: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
    }
}

