import AuthenticationServices
import CryptoKit
import Foundation
import Combine

/// Spotify Web API integration using OAuth 2.0 Authorization Code with PKCE.
///
/// No server required – the PKCE flow is fully client-side and is Spotify's
/// recommended approach for mobile apps.
///
/// What you get without the Spotify iOS SDK:
///   - Search tracks, albums, playlists
///   - 30-second preview URLs (publicly hosted MP3s – legally streamable)
///   - Full metadata: artwork, artist, duration, popularity
///
/// For full-track playback the README explains adding SpotifyiOS SDK, which
/// remote-controls the official Spotify app while our engine handles YouTube
/// mixing and volume/pan DSP.
@MainActor
final class SpotifyAPIService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {

    // MARK: – Configuration (fill in your Spotify Developer Dashboard values)

    struct Config {
        static let clientID     = "YOUR_SPOTIFY_CLIENT_ID"
        static let redirectURI  = "audiomixer://spotify-callback"
        static let scopes       = "user-read-playback-state user-modify-playback-state streaming"
    }

    // MARK: – Published state

    @Published var isAuthenticated = false
    @Published var searchResults: [SpotifyTrack] = []
    @Published var currentTrack: SpotifyTrack?
    @Published var isSearching = false
    @Published var authError: String?

    // MARK: – Private state

    private var accessToken: String?
    private var tokenExpiry: Date?
    private var refreshToken: String?
    private var codeVerifier: String?
    private var searchTask: Task<Void, Never>?

    // MARK: – PKCE Helpers

    private func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 64)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncoded()
    }

    // MARK: – Auth Flow

    func authenticate() {
        let verifier = generateCodeVerifier()
        codeVerifier = verifier
        let challenge = codeChallenge(from: verifier)

        var comps = URLComponents(string: "https://accounts.spotify.com/authorize")!
        comps.queryItems = [
            URLQueryItem(name: "client_id",             value: Config.clientID),
            URLQueryItem(name: "response_type",         value: "code"),
            URLQueryItem(name: "redirect_uri",          value: Config.redirectURI),
            URLQueryItem(name: "scope",                 value: Config.scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge",        value: challenge),
        ]

        guard let url = comps.url else { return }

        let session = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "audiomixer"
        ) { [weak self] callbackURL, error in
            guard let self else { return }
            if let error {
                self.authError = error.localizedDescription
                return
            }
            guard
                let callbackURL,
                let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "code" })?.value
            else {
                self.authError = "No auth code in callback"
                return
            }
            Task { await self.exchangeCode(code) }
        }
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }

    private func exchangeCode(_ code: String) async {
        guard let verifier = codeVerifier else { return }

        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type":    "authorization_code",
            "code":          code,
            "redirect_uri":  Config.redirectURI,
            "client_id":     Config.clientID,
            "code_verifier": verifier,
        ].percentEncoded()
        req.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
            accessToken  = tokenResponse.access_token
            refreshToken = tokenResponse.refresh_token
            tokenExpiry  = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
            isAuthenticated = true
        } catch {
            authError = "Token exchange failed: \(error.localizedDescription)"
        }
    }

    private func refreshAccessToken() async throws {
        guard let rt = refreshToken else { throw APIError.notAuthenticated }

        var req = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type":    "refresh_token",
            "refresh_token": rt,
            "client_id":     Config.clientID,
        ].percentEncoded()
        req.httpBody = body

        let (data, _) = try await URLSession.shared.data(for: req)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = tokenResponse.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        if let newRT = tokenResponse.refresh_token { refreshToken = newRT }
    }

    // MARK: – Token management

    private func validToken() async throws -> String {
        if let expiry = tokenExpiry, expiry < Date().addingTimeInterval(60) {
            try await refreshAccessToken()
        }
        guard let token = accessToken else { throw APIError.notAuthenticated }
        return token
    }

    // MARK: – Search

    func search(query: String) {
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            do {
                let token = try await validToken()
                var comps = URLComponents(string: "https://api.spotify.com/v1/search")!
                comps.queryItems = [
                    URLQueryItem(name: "q",     value: query),
                    URLQueryItem(name: "type",  value: "track"),
                    URLQueryItem(name: "limit", value: "20"),
                ]
                var req = URLRequest(url: comps.url!)
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

                let (data, _) = try await URLSession.shared.data(for: req)
                let response  = try JSONDecoder().decode(SearchResponse.self, from: data)
                if !Task.isCancelled {
                    searchResults = response.tracks.items.compactMap(SpotifyTrack.init)
                }
            } catch {
                if !Task.isCancelled {
                    authError = error.localizedDescription
                }
            }
        }
    }

    // MARK: – ASWebAuthenticationPresentationContextProviding

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        DispatchQueue.main.sync {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? UIWindow()
        }
    }
}

// MARK: – Errors

enum APIError: LocalizedError {
    case notAuthenticated
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated with Spotify"
        }
    }
}

// MARK: – Response models (Codable)

private struct TokenResponse: Codable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
}

private struct SearchResponse: Codable {
    struct Tracks: Codable {
        let items: [RawTrack]
    }
    let tracks: Tracks
}

struct RawTrack: Codable {
    struct Album: Codable {
        struct Image: Codable { let url: String; let width: Int?; let height: Int? }
        let name: String
        let images: [Image]
    }
    struct Artist: Codable { let name: String }
    let id: String
    let name: String
    let artists: [Artist]
    let album: Album
    let duration_ms: Int
    let preview_url: String?
    let popularity: Int
}

// MARK: – Helpers

private extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { key, value in
            let escapedKey   = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
