import SwiftUI

@main
struct AudioMixerApp: App {
    @StateObject private var audioEngine   = AudioEngineService()
    @StateObject private var spotifyService = SpotifyAPIService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioEngine)
                .environmentObject(spotifyService)
                .onAppear {
                    audioEngine.setup()
                }
                // Handle Spotify OAuth callback deep-link
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // The ASWebAuthenticationSession callback is handled internally by
        // SpotifyAPIService; nothing extra needed here unless you want to
        // support universal links in addition to the custom scheme.
        _ = url  // suppress unused-variable warning
    }
}
